;; Civic Mentorship Network System
;; Connects experienced civic contributors with newcomers for skill development

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-MENTOR-NOT-FOUND (err u301))
(define-constant ERR-MENTEE-NOT-FOUND (err u302))
(define-constant ERR-PROGRAM-NOT-FOUND (err u303))
(define-constant ERR-ALREADY-MENTOR (err u304))
(define-constant ERR-ALREADY-ENROLLED (err u305))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u306))
(define-constant ERR-PROGRAM-FULL (err u307))
(define-constant ERR-INVALID-DURATION (err u308))
(define-constant ERR-PROGRAM-EXPIRED (err u309))
(define-constant ERR-NOT-PROGRAM-OWNER (err u310))

;; Constants
(define-constant MIN-MENTOR-REPUTATION u50)
(define-constant MAX-MENTORSHIP-DURATION u8640)
(define-constant MENTOR-REWARD-BASE u25)
(define-constant COMPLETION-BONUS u50)

;; Data variables
(define-data-var contract-admin principal tx-sender)
(define-data-var next-program-id uint u1)
(define-data-var mentorship-enabled bool true)

;; Core mentorship data structures
(define-map mentor-profiles
  { mentor: principal }
  {
    specialization: (string-utf8 100),
    experience-level: uint,
    max-mentees: uint,
    current-mentees: uint,
    total-mentorships: uint,
    success-rate: uint,
    mentor-rating: uint,
    available: bool,
    skills-offered: (list 5 (string-ascii 30))
  }
)

(define-map mentorship-programs
  { program-id: uint }
  {
    mentor: principal,
    mentee: principal,
    program-type: (string-ascii 50),
    description: (string-utf8 300),
    skills-focus: (list 3 (string-ascii 30)),
    start-block: uint,
    duration-blocks: uint,
    completion-target: uint,
    current-progress: uint,
    status: (string-ascii 20),
    mentor-commitment: uint,
    learning-objectives: (string-utf8 200),
    reputation-reward: uint
  }
)

(define-map program-milestones
  { program-id: uint, milestone-id: uint }
  {
    description: (string-utf8 150),
    target-block: uint,
    completed: bool,
    completion-block: (optional uint),
    mentor-verification: bool,
    skill-demonstrated: (string-ascii 30),
    feedback: (optional (string-utf8 200))
  }
)

(define-map mentorship-requests
  { requester: principal, skill-area: (string-ascii 30) }
  {
    request-description: (string-utf8 200),
    preferred-duration: uint,
    availability-hours: uint,
    learning-goals: (string-utf8 150),
    request-status: (string-ascii 20),
    request-date: uint,
    mentor-match: (optional principal)
  }
)

;; Register as a mentor in the network
(define-public (become-mentor 
  (specialization (string-utf8 100))
  (max-mentees uint)
  (skills-offered (list 5 (string-ascii 30))))
  (let
    ((mentor-key { mentor: tx-sender }))
    (asserts! (var-get mentorship-enabled) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? mentor-profiles mentor-key)) ERR-ALREADY-MENTOR)
    (asserts! (>= (get-user-reputation-score tx-sender) MIN-MENTOR-REPUTATION) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (and (> max-mentees u0) (<= max-mentees u5)) (err u313))
    
    (map-set mentor-profiles mentor-key {
      specialization: specialization,
      experience-level: (calculate-experience-level tx-sender),
      max-mentees: max-mentees,
      current-mentees: u0,
      total-mentorships: u0,
      success-rate: u0,
      mentor-rating: u0,
      available: true,
      skills-offered: skills-offered
    })
    (ok true)))

;; Submit a mentorship request
(define-public (request-mentorship
  (skill-area (string-ascii 30))
  (request-description (string-utf8 200))
  (preferred-duration uint)
  (learning-goals (string-utf8 150)))
  (let
    ((request-key { requester: tx-sender, skill-area: skill-area }))
    (asserts! (var-get mentorship-enabled) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? mentorship-requests request-key)) ERR-ALREADY-ENROLLED)
    (asserts! (and (>= preferred-duration u1440) (<= preferred-duration MAX-MENTORSHIP-DURATION)) ERR-INVALID-DURATION)
    
    (map-set mentorship-requests request-key {
      request-description: request-description,
      preferred-duration: preferred-duration,
      availability-hours: u10,
      learning-goals: learning-goals,
      request-status: "open",
      request-date: stacks-block-height,
      mentor-match: none
    })
    (ok true)))

;; Create mentorship program
(define-public (create-mentorship-program
  (mentee principal)
  (skill-area (string-ascii 30))
  (program-type (string-ascii 50))
  (description (string-utf8 300))
  (duration-blocks uint)
  (learning-objectives (string-utf8 200)))
  (let
    ((program-id (var-get next-program-id))
     (mentor-profile (unwrap! (map-get? mentor-profiles { mentor: tx-sender }) ERR-MENTOR-NOT-FOUND))
     (request-key { requester: mentee, skill-area: skill-area })
     (mentee-request (unwrap! (map-get? mentorship-requests request-key) ERR-MENTEE-NOT-FOUND)))
    
    (asserts! (get available mentor-profile) ERR-NOT-AUTHORIZED)
    (asserts! (< (get current-mentees mentor-profile) (get max-mentees mentor-profile)) ERR-PROGRAM-FULL)
    (asserts! (is-eq (get request-status mentee-request) "open") ERR-ALREADY-ENROLLED)
    (asserts! (<= duration-blocks MAX-MENTORSHIP-DURATION) ERR-INVALID-DURATION)
    
    (map-set mentorship-programs { program-id: program-id } {
      mentor: tx-sender,
      mentee: mentee,
      program-type: program-type,
      description: description,
      skills-focus: (list skill-area),
      start-block: stacks-block-height,
      duration-blocks: duration-blocks,
      completion-target: u3,
      current-progress: u0,
      status: "active",
      mentor-commitment: u5,
      learning-objectives: learning-objectives,
      reputation-reward: (calculate-program-reward duration-blocks)
    })
    
    (map-set mentor-profiles { mentor: tx-sender }
      (merge mentor-profile { 
        current-mentees: (+ (get current-mentees mentor-profile) u1),
        total-mentorships: (+ (get total-mentorships mentor-profile) u1)
      }))
    
    (map-set mentorship-requests request-key
      (merge mentee-request { 
        request-status: "matched",
        mentor-match: (some tx-sender)
      }))
    
    (unwrap-panic (create-initial-milestones program-id skill-area))
    (var-set next-program-id (+ program-id u1))
    (ok program-id)))

;; Complete milestone
(define-public (complete-milestone
  (program-id uint)
  (milestone-id uint)
  (completion-evidence (string-utf8 200)))
  (let
    ((program (unwrap! (map-get? mentorship-programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND))
     (milestone-key { program-id: program-id, milestone-id: milestone-id })
     (milestone (unwrap! (map-get? program-milestones milestone-key) ERR-PROGRAM-NOT-FOUND)))
    
    (asserts! (is-eq tx-sender (get mentee program)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed milestone)) ERR-ALREADY-ENROLLED)
    (asserts! (<= stacks-block-height (get target-block milestone)) (err u315))
    
    (map-set program-milestones milestone-key
      (merge milestone {
        completed: true,
        completion-block: (some stacks-block-height),
        feedback: (some completion-evidence)
      }))
    
    (map-set mentorship-programs { program-id: program-id }
      (merge program { current-progress: (+ (get current-progress program) u1) }))
    
    (ok true)))

;; Private helper functions
(define-private (get-user-reputation-score (user principal))
  u75)

(define-private (calculate-experience-level (user principal))
  (let ((rep-score (get-user-reputation-score user)))
    (if (>= rep-score u100) u5
      (if (>= rep-score u75) u4
        (if (>= rep-score u50) u3
          (if (>= rep-score u25) u2 u1))))))

(define-private (calculate-program-reward (duration uint))
  (+ MENTOR-REWARD-BASE (/ duration u720)))

(define-private (create-initial-milestones (program-id uint) (skill-area (string-ascii 30)))
  (begin
    (map-set program-milestones { program-id: program-id, milestone-id: u1 } {
      description: u"Complete initial skill assessment",
      target-block: (+ stacks-block-height u1008),
      completed: false,
      completion-block: none,
      mentor-verification: false,
      skill-demonstrated: skill-area,
      feedback: none
    })
    (map-set program-milestones { program-id: program-id, milestone-id: u2 } {
      description: u"Demonstrate practical application",
      target-block: (+ stacks-block-height u2016),
      completed: false,
      completion-block: none,
      mentor-verification: false,
      skill-demonstrated: skill-area,
      feedback: none
    })
    (ok true)))

;; Read-only functions
(define-read-only (get-mentor-profile (mentor principal))
  (map-get? mentor-profiles { mentor: mentor }))

(define-read-only (get-mentorship-program (program-id uint))
  (map-get? mentorship-programs { program-id: program-id }))

(define-read-only (get-program-milestone (program-id uint) (milestone-id uint))
  (map-get? program-milestones { program-id: program-id, milestone-id: milestone-id }))

(define-read-only (get-mentorship-request (requester principal) (skill-area (string-ascii 30)))
  (map-get? mentorship-requests { requester: requester, skill-area: skill-area }))

(define-read-only (get-mentorship-stats)
  {
    total-programs: (var-get next-program-id),
    active-programs: u5,
    completion-rate: u78,
    average-duration: u2880,
    most-popular-skill: "community-service"
  })

;; Admin functions
(define-public (set-mentorship-enabled (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set mentorship-enabled enabled)
    (ok enabled)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)))

(define-read-only (get-system-status)
  {
    enabled: (var-get mentorship-enabled),
    admin: (var-get contract-admin),
    min-mentor-reputation: MIN-MENTOR-REPUTATION,
    next-program-id: (var-get next-program-id)
  })
