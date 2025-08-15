
(define-non-fungible-token civic-reputation uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-wrong-commission (err u103))
(define-constant err-listing-expired (err u104))
(define-constant err-nft-not-found (err u105))
(define-constant err-sender-equals-recipient (err u106))
(define-constant err-invalid-contribution-type (err u107))
(define-constant err-insufficient-reputation (err u108))
(define-constant err-challenge-not-found (err u109))
(define-constant err-challenge-inactive (err u110))
(define-constant err-challenge-expired (err u111))
(define-constant err-already-participated (err u112))
(define-constant err-voting-closed (err u113))
(define-constant err-already-voted (err u114))
(define-constant err-challenge-not-approved (err u115))
(define-constant err-insufficient-participants (err u116))
(define-constant err-challenge-already-completed (err u117))
(define-constant err-not-challenge-creator (err u118))
(define-constant err-bond-not-found (err u119))
(define-constant err-bond-not-active (err u120))
(define-constant err-bond-already-funded (err u121))
(define-constant err-insufficient-funding (err u122))
(define-constant err-bond-expired (err u123))
(define-constant err-not-bond-creator (err u124))
(define-constant err-already-funded-bond (err u125))
(define-constant err-minimum-funding-not-met (err u126))
(define-constant err-bond-not-ready-for-payout (err u127))
(define-constant err-impact-already-verified (err u128))
(define-constant err-bond-outcome-not-achieved (err u129))

(define-data-var last-token-id uint u0)
(define-data-var last-challenge-id uint u0)
(define-data-var last-bond-id uint u0)
(define-data-var total-contributions uint u0)

(define-map token-count principal uint)
(define-map token-uri uint (optional (string-utf8 256)))
(define-map civic-contributions uint {
    contributor: principal,
    contribution-type: (string-ascii 50),
    description: (string-utf8 500),
    impact-score: uint,
    timestamp: uint,
    verified: bool,
    verifier: (optional principal)
})

(define-map user-reputation principal {
    total-score: uint,
    contribution-count: uint,
    verified-contributions: uint,
    reputation-level: (string-ascii 20),
    last-contribution: uint
})

(define-map contribution-types (string-ascii 50) {
    base-score: uint,
    multiplier: uint,
    requires-verification: bool
})

(define-map verifiers principal bool)

(define-map community-challenges uint {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    category: (string-ascii 50),
    target-participants: uint,
    reward-per-participant: uint,
    start-block: uint,
    end-block: uint,
    voting-end-block: uint,
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    participants: (list 100 principal),
    total-participants: uint,
    completion-threshold: uint,
    completion-submissions: uint,
    is-approved: bool,
    total-reward-pool: uint
})

(define-map challenge-votes {challenge-id: uint, voter: principal} bool)
(define-map challenge-participants {challenge-id: uint, participant: principal} {
    joined-block: uint,
    completed: bool,
    completion-proof: (string-utf8 300),
    reward-claimed: bool
})

(define-map challenge-completions uint {
    challenge-id: uint,
    participant: principal,
    submission-block: uint,
    verified: bool,
    verifier: (optional principal)
})

;; Impact Bonds System - Community-funded outcome-based civic projects
(define-map impact-bonds uint {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    category: (string-ascii 50),
    target-funding: uint,
    current-funding: uint,
    outcome-metric: (string-utf8 200),
    target-outcome: uint,
    current-outcome: uint,
    payout-rate: uint, ;; percentage return for funders (basis points)
    creation-block: uint,
    funding-deadline: uint,
    outcome-deadline: uint,
    status: (string-ascii 20), ;; "funding", "active", "completed", "failed", "expired"
    is-outcome-verified: bool,
    total-funders: uint,
    reputation-bonus: uint
})

(define-map bond-funders {bond-id: uint, funder: principal} {
    amount-funded: uint,
    funding-block: uint,
    reward-claimed: bool,
    proportional-share: uint ;; basis points of total funding
})

(define-map bond-outcomes uint {
    bond-id: uint,
    outcome-value: uint,
    verification-block: uint,
    verifier: principal,
    evidence: (string-utf8 300),
    achievement-percentage: uint
})

(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set contribution-types "community-service" {base-score: u10, multiplier: u1, requires-verification: true})
        (map-set contribution-types "environmental-action" {base-score: u15, multiplier: u1, requires-verification: true})
        (map-set contribution-types "civic-participation" {base-score: u20, multiplier: u1, requires-verification: false})
        (map-set contribution-types "volunteer-work" {base-score: u12, multiplier: u1, requires-verification: true})
        (map-set contribution-types "public-advocacy" {base-score: u18, multiplier: u1, requires-verification: false})
        (map-set contribution-types "education-outreach" {base-score: u14, multiplier: u1, requires-verification: true})
        (ok true)
    )
)

(define-public (add-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set verifiers verifier true)
        (ok true)
    )
)

(define-public (remove-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete verifiers verifier)
        (ok true)
    )
)

(define-public (submit-contribution (contribution-type (string-ascii 50)) (description (string-utf8 500)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (contribution-info (unwrap! (map-get? contribution-types contribution-type) err-invalid-contribution-type))
            (base-score (get base-score contribution-info))
            (requires-verification (get requires-verification contribution-info))
            (current-block stacks-block-height)
        )
        (var-set last-token-id token-id)
        (var-set total-contributions (+ (var-get total-contributions) u1))
        (try! (nft-mint? civic-reputation token-id tx-sender))
        (map-set civic-contributions token-id {
            contributor: tx-sender,
            contribution-type: contribution-type,
            description: description,
            impact-score: base-score,
            timestamp: current-block,
            verified: (not requires-verification),
            verifier: none
        })
        (map-set token-count tx-sender (+ (default-to u0 (map-get? token-count tx-sender)) u1))
        (update-user-reputation tx-sender base-score (not requires-verification))
        (ok token-id)
    )
)

(define-public (verify-contribution (token-id uint))
    (let
        (
            (contribution (unwrap! (map-get? civic-contributions token-id) err-nft-not-found))
            (is-verifier (default-to false (map-get? verifiers tx-sender)))
        )
        (asserts! is-verifier err-owner-only)
        (asserts! (not (get verified contribution)) (err u109))
        (map-set civic-contributions token-id (merge contribution {
            verified: true,
            verifier: (some tx-sender)
        }))
        (let
            (
                (contributor (get contributor contribution))
                (impact-score (get impact-score contribution))
            )
            (update-verified-reputation contributor impact-score)
        )
        (ok true)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (not (is-eq sender recipient)) err-sender-equals-recipient)
        (try! (nft-transfer? civic-reputation token-id sender recipient))
        (map-set token-count sender (- (default-to u0 (map-get? token-count sender)) u1))
        (map-set token-count recipient (+ (default-to u0 (map-get? token-count recipient)) u1))
        (ok true)
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set token-uri token-id (some uri))
        (ok true)
    )
)

(define-private (update-user-reputation (user principal) (score uint) (is-verified bool))
    (let
        (
            (current-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation user)))
            (new-total-score (+ (get total-score current-rep) score))
            (new-contribution-count (+ (get contribution-count current-rep) u1))
            (new-verified-count (if is-verified (+ (get verified-contributions current-rep) u1) (get verified-contributions current-rep)))
            (new-level (calculate-reputation-level new-total-score new-verified-count))
        )
        (map-set user-reputation user {
            total-score: new-total-score,
            contribution-count: new-contribution-count,
            verified-contributions: new-verified-count,
            reputation-level: new-level,
            last-contribution: stacks-block-height
        })
    )
)

(define-private (update-verified-reputation (user principal) (score uint))
    (let
        (
            (current-rep (unwrap-panic (map-get? user-reputation user)))
            (new-verified-count (+ (get verified-contributions current-rep) u1))
            (new-level (calculate-reputation-level (get total-score current-rep) new-verified-count))
        )
        (map-set user-reputation user (merge current-rep {
            verified-contributions: new-verified-count,
            reputation-level: new-level
        }))
    )
)

(define-private (calculate-reputation-level (total-score uint) (verified-count uint))
    (if (and (>= total-score u100) (>= verified-count u10))
        "civic-champion"
        (if (and (>= total-score u50) (>= verified-count u5))
            "community-leader"
            (if (and (>= total-score u25) (>= verified-count u3))
                "active-citizen"
                (if (>= total-score u10)
                    "contributor"
                    "newcomer"
                )
            )
        )
    )
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uri token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? civic-reputation token-id))
)

(define-read-only (get-contribution-details (token-id uint))
    (map-get? civic-contributions token-id)
)

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation user)
)

(define-read-only (get-user-token-count (user principal))
    (default-to u0 (map-get? token-count user))
)

(define-read-only (get-total-contributions)
    (var-get total-contributions)
)

(define-read-only (get-contribution-type-info (contribution-type (string-ascii 50)))
    (map-get? contribution-types contribution-type)
)

(define-read-only (is-verifier (user principal))
    (default-to false (map-get? verifiers user))
)

(define-public (create-community-challenge 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (category (string-ascii 50))
    (target-participants uint)
    (reward-per-participant uint)
    (duration-blocks uint)
    (voting-duration-blocks uint)
    (completion-threshold uint))
    (let
        (
            (challenge-id (+ (var-get last-challenge-id) u1))
            (current-block stacks-block-height)
            (voting-end-block (+ current-block voting-duration-blocks))
            (start-block (+ voting-end-block u1))
            (end-block (+ start-block duration-blocks))
            (total-reward-pool (* target-participants reward-per-participant))
            (user-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation tx-sender)))
        )
        (asserts! (>= (get total-score user-rep) u25) err-insufficient-reputation)
        (asserts! (>= target-participants u3) (err u120))
        (asserts! (<= target-participants u100) (err u121))
        (asserts! (>= completion-threshold u1) (err u122))
        (asserts! (<= completion-threshold target-participants) (err u123))
        (var-set last-challenge-id challenge-id)
        (map-set community-challenges challenge-id {
            creator: tx-sender,
            title: title,
            description: description,
            category: category,
            target-participants: target-participants,
            reward-per-participant: reward-per-participant,
            start-block: start-block,
            end-block: end-block,
            voting-end-block: voting-end-block,
            status: "voting",
            votes-for: u0,
            votes-against: u0,
            participants: (list),
            total-participants: u0,
            completion-threshold: completion-threshold,
            completion-submissions: u0,
            is-approved: false,
            total-reward-pool: total-reward-pool
        })
        (ok challenge-id)
    )
)

(define-public (vote-on-challenge (challenge-id uint) (vote-for bool))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
            (voter-key {challenge-id: challenge-id, voter: tx-sender})
            (user-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation tx-sender)))
        )
        (asserts! (is-eq (get status challenge) "voting") err-voting-closed)
        (asserts! (<= current-block (get voting-end-block challenge)) err-voting-closed)
        (asserts! (>= (get total-score user-rep) u10) err-insufficient-reputation)
        (asserts! (is-none (map-get? challenge-votes voter-key)) err-already-voted)
        (map-set challenge-votes voter-key vote-for)
        (map-set community-challenges challenge-id (merge challenge {
            votes-for: (if vote-for (+ (get votes-for challenge) u1) (get votes-for challenge)),
            votes-against: (if vote-for (get votes-against challenge) (+ (get votes-against challenge) u1))
        }))
        (ok true)
    )
)

(define-public (finalize-challenge-voting (challenge-id uint))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
            (votes-for (get votes-for challenge))
            (votes-against (get votes-against challenge))
            (total-votes (+ votes-for votes-against))
            (approval-threshold (/ total-votes u2))
        )
        (asserts! (is-eq (get status challenge) "voting") err-voting-closed)
        (asserts! (> current-block (get voting-end-block challenge)) err-voting-closed)
        (asserts! (>= total-votes u3) err-insufficient-participants)
        (if (> votes-for approval-threshold)
            (map-set community-challenges challenge-id (merge challenge {
                status: "active",
                is-approved: true
            }))
            (map-set community-challenges challenge-id (merge challenge {
                status: "rejected"
            }))
        )
        (ok true)
    )
)

(define-public (join-challenge (challenge-id uint))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
            (participant-key {challenge-id: challenge-id, participant: tx-sender})
            (current-participants (get participants challenge))
            (user-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation tx-sender)))
        )
        (asserts! (get is-approved challenge) err-challenge-not-approved)
        (asserts! (is-eq (get status challenge) "active") err-challenge-inactive)
        (asserts! (>= current-block (get start-block challenge)) err-challenge-inactive)
        (asserts! (<= current-block (get end-block challenge)) err-challenge-expired)
        (asserts! (< (get total-participants challenge) (get target-participants challenge)) err-insufficient-participants)
        (asserts! (>= (get total-score user-rep) u5) err-insufficient-reputation)
        (asserts! (is-none (map-get? challenge-participants participant-key)) err-already-participated)
        (map-set challenge-participants participant-key {
            joined-block: current-block,
            completed: false,
            completion-proof: u"",
            reward-claimed: false
        })
        (map-set community-challenges challenge-id (merge challenge {
            participants: (unwrap-panic (as-max-len? (append current-participants tx-sender) u100)),
            total-participants: (+ (get total-participants challenge) u1)
        }))
        (ok true)
    )
)

(define-public (submit-challenge-completion (challenge-id uint) (completion-proof (string-utf8 300)))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
            (participant-key {challenge-id: challenge-id, participant: tx-sender})
            (participant-data (unwrap! (map-get? challenge-participants participant-key) err-already-participated))
            (completion-id (+ (var-get last-token-id) u1))
        )
        (asserts! (is-eq (get status challenge) "active") err-challenge-inactive)
        (asserts! (<= current-block (get end-block challenge)) err-challenge-expired)
        (asserts! (not (get completed participant-data)) err-challenge-already-completed)
        (var-set last-token-id completion-id)
        (map-set challenge-participants participant-key (merge participant-data {
            completed: true,
            completion-proof: completion-proof
        }))
        (map-set challenge-completions completion-id {
            challenge-id: challenge-id,
            participant: tx-sender,
            submission-block: current-block,
            verified: false,
            verifier: none
        })
        (map-set community-challenges challenge-id (merge challenge {
            completion-submissions: (+ (get completion-submissions challenge) u1)
        }))
        (ok completion-id)
    )
)

(define-public (verify-challenge-completion (completion-id uint))
    (let
        (
            (completion (unwrap! (map-get? challenge-completions completion-id) err-nft-not-found))
            (challenge-id (get challenge-id completion))
            (participant (get participant completion))
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (is-verifier (default-to false (map-get? verifiers tx-sender)))
            (participant-key {challenge-id: challenge-id, participant: participant})
        )
        (asserts! is-verifier err-owner-only)
        (asserts! (not (get verified completion)) (err u130))
        (map-set challenge-completions completion-id (merge completion {
            verified: true,
            verifier: (some tx-sender)
        }))
        (ok true)
    )
)

(define-public (claim-challenge-reward (challenge-id uint))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
            (participant-key {challenge-id: challenge-id, participant: tx-sender})
            (participant-data (unwrap! (map-get? challenge-participants participant-key) err-already-participated))
            (reward-amount (get reward-per-participant challenge))
        )
        (asserts! (> current-block (get end-block challenge)) err-challenge-expired)
        (asserts! (get completed participant-data) err-challenge-already-completed)
        (asserts! (not (get reward-claimed participant-data)) (err u131))
        (asserts! (>= (get completion-submissions challenge) (get completion-threshold challenge)) err-insufficient-participants)
        (map-set challenge-participants participant-key (merge participant-data {
            reward-claimed: true
        }))
        (update-user-reputation tx-sender reward-amount true)
        (ok reward-amount)
    )
)

(define-public (close-challenge (challenge-id uint))
    (let
        (
            (challenge (unwrap! (map-get? community-challenges challenge-id) err-challenge-not-found))
            (current-block stacks-block-height)
        )
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get creator challenge))) err-not-challenge-creator)
        (asserts! (> current-block (get end-block challenge)) err-challenge-expired)
        (map-set community-challenges challenge-id (merge challenge {
            status: "completed"
        }))
        (ok true)
    )
)

(define-read-only (get-challenge-details (challenge-id uint))
    (map-get? community-challenges challenge-id)
)

(define-read-only (get-challenge-participant-data (challenge-id uint) (participant principal))
    (map-get? challenge-participants {challenge-id: challenge-id, participant: participant})
)

(define-read-only (get-challenge-vote (challenge-id uint) (voter principal))
    (map-get? challenge-votes {challenge-id: challenge-id, voter: voter})
)

(define-read-only (get-challenge-completion (completion-id uint))
    (map-get? challenge-completions completion-id)
)

(define-read-only (get-last-challenge-id)
    (var-get last-challenge-id)
)

(define-read-only (get-active-challenges)
    (var-get last-challenge-id)
)

;; Impact Bonds System Functions

(define-public (create-impact-bond 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (category (string-ascii 50))
    (target-funding uint)
    (outcome-metric (string-utf8 200))
    (target-outcome uint)
    (payout-rate uint)
    (funding-duration-blocks uint)
    (outcome-duration-blocks uint)
    (reputation-bonus uint))
    (let
        (
            (bond-id (+ (var-get last-bond-id) u1))
            (current-block stacks-block-height)
            (funding-deadline (+ current-block funding-duration-blocks))
            (outcome-deadline (+ funding-deadline outcome-duration-blocks))
            (user-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation tx-sender)))
        )
        ;; Require minimum reputation to create bonds
        (asserts! (>= (get total-score user-rep) u50) err-insufficient-reputation)
        (asserts! (>= target-funding u1000000) (err u130)) ;; Minimum 0.01 STX
        (asserts! (>= target-outcome u1) (err u131))
        (asserts! (<= payout-rate u2000) (err u132)) ;; Max 20% return
        (asserts! (>= payout-rate u500) (err u133)) ;; Min 5% return
        
        (var-set last-bond-id bond-id)
        (map-set impact-bonds bond-id {
            creator: tx-sender,
            title: title,
            description: description,
            category: category,
            target-funding: target-funding,
            current-funding: u0,
            outcome-metric: outcome-metric,
            target-outcome: target-outcome,
            current-outcome: u0,
            payout-rate: payout-rate,
            creation-block: current-block,
            funding-deadline: funding-deadline,
            outcome-deadline: outcome-deadline,
            status: "funding",
            is-outcome-verified: false,
            total-funders: u0,
            reputation-bonus: reputation-bonus
        })
        (ok bond-id)
    )
)

(define-public (fund-impact-bond (bond-id uint) (amount uint))
    (let
        (
            (bond (unwrap! (map-get? impact-bonds bond-id) err-bond-not-found))
            (current-block stacks-block-height)
            (funder-key {bond-id: bond-id, funder: tx-sender})
            (existing-funding (map-get? bond-funders funder-key))
            (new-total-funding (+ (get current-funding bond) amount))
            (user-rep (default-to {total-score: u0, contribution-count: u0, verified-contributions: u0, reputation-level: "newcomer", last-contribution: u0} (map-get? user-reputation tx-sender)))
        )
        ;; Validation checks
        (asserts! (is-eq (get status bond) "funding") err-bond-not-active)
        (asserts! (<= current-block (get funding-deadline bond)) err-bond-expired)
        (asserts! (>= (get total-score user-rep) u10) err-insufficient-reputation)
        (asserts! (>= amount u100000) (err u134)) ;; Minimum 0.001 STX funding
        (asserts! (<= new-total-funding (get target-funding bond)) err-insufficient-funding)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update or create funder record
        (match existing-funding
            existing-data
            (let
                (
                    (new-amount (+ (get amount-funded existing-data) amount))
                    (new-share (/ (* new-amount u10000) new-total-funding))
                )
                (map-set bond-funders funder-key (merge existing-data {
                    amount-funded: new-amount,
                    proportional-share: new-share
                }))
            )
            (let
                (
                    (share (/ (* amount u10000) new-total-funding))
                )
                (map-set bond-funders funder-key {
                    amount-funded: amount,
                    funding-block: current-block,
                    reward-claimed: false,
                    proportional-share: share
                })
                (map-set impact-bonds bond-id (merge bond {
                    total-funders: (+ (get total-funders bond) u1)
                }))
            )
        )
        
        ;; Update bond funding
        (map-set impact-bonds bond-id (merge bond {
            current-funding: new-total-funding,
            status: (if (>= new-total-funding (get target-funding bond)) "active" "funding")
        }))
        
        (ok new-total-funding)
    )
)

(define-public (verify-bond-outcome (bond-id uint) (outcome-value uint) (evidence (string-utf8 300)))
    (let
        (
            (bond (unwrap! (map-get? impact-bonds bond-id) err-bond-not-found))
            (current-block stacks-block-height)
            (is-verifier (default-to false (map-get? verifiers tx-sender)))
            (achievement-percentage (/ (* outcome-value u10000) (get target-outcome bond)))
        )
        ;; Only verifiers can verify outcomes
        (asserts! is-verifier err-owner-only)
        (asserts! (is-eq (get status bond) "active") err-bond-not-active)
        (asserts! (> current-block (get outcome-deadline bond)) err-bond-expired)
        (asserts! (not (get is-outcome-verified bond)) err-impact-already-verified)
        
        ;; Record outcome verification
        (map-set bond-outcomes bond-id {
            bond-id: bond-id,
            outcome-value: outcome-value,
            verification-block: current-block,
            verifier: tx-sender,
            evidence: evidence,
            achievement-percentage: achievement-percentage
        })
        
        ;; Update bond status based on outcome achievement
        (map-set impact-bonds bond-id (merge bond {
            current-outcome: outcome-value,
            is-outcome-verified: true,
            status: (if (>= outcome-value (get target-outcome bond)) "completed" "failed")
        }))
        
        ;; Award reputation bonus to bond creator if successful
        (if (>= outcome-value (get target-outcome bond))
            (begin
                (update-user-reputation (get creator bond) (get reputation-bonus bond) true)
                (ok true)
            )
            (ok true)
        )
    )
)

(define-public (claim-bond-rewards (bond-id uint))
    (let
        (
            (bond (unwrap! (map-get? impact-bonds bond-id) err-bond-not-found))
            (funder-key {bond-id: bond-id, funder: tx-sender})
            (funder-data (unwrap! (map-get? bond-funders funder-key) err-already-funded-bond))
            (outcome-data (unwrap! (map-get? bond-outcomes bond-id) err-bond-not-ready-for-payout))
            (achievement-rate (get achievement-percentage outcome-data))
            (base-return (get amount-funded funder-data))
            (bonus-return (/ (* base-return (get payout-rate bond) achievement-rate) u1000000))
            (total-return (+ base-return bonus-return))
        )
        ;; Validation checks
        (asserts! (get is-outcome-verified bond) err-bond-not-ready-for-payout)
        (asserts! (not (get reward-claimed funder-data)) (err u135))
        (asserts! (>= achievement-rate u1000) err-bond-outcome-not-achieved) ;; At least 10% achievement
        
        ;; Mark reward as claimed
        (map-set bond-funders funder-key (merge funder-data {
            reward-claimed: true
        }))
        
        ;; Transfer rewards back to funder
        (try! (as-contract (stx-transfer? total-return tx-sender tx-sender)))
        
        ;; Award reputation points for successful funding
        (let
            (
                (rep-reward (/ (get amount-funded funder-data) u100000)) ;; 1 point per 0.001 STX
            )
            (update-user-reputation tx-sender rep-reward true)
        )
        
        (ok total-return)
    )
)

(define-public (reclaim-failed-bond-funding (bond-id uint))
    (let
        (
            (bond (unwrap! (map-get? impact-bonds bond-id) err-bond-not-found))
            (funder-key {bond-id: bond-id, funder: tx-sender})
            (funder-data (unwrap! (map-get? bond-funders funder-key) err-already-funded-bond))
            (current-block stacks-block-height)
        )
        ;; Can only reclaim if bond failed funding deadline or outcome target
        (asserts! (or 
            (and (> current-block (get funding-deadline bond)) 
                 (< (get current-funding bond) (get target-funding bond)))
            (and (get is-outcome-verified bond) 
                 (is-eq (get status bond) "failed"))) err-bond-not-ready-for-payout)
        (asserts! (not (get reward-claimed funder-data)) (err u135))
        
        ;; Mark as reclaimed
        (map-set bond-funders funder-key (merge funder-data {
            reward-claimed: true
        }))
        
        ;; Return original funding
        (try! (as-contract (stx-transfer? (get amount-funded funder-data) tx-sender tx-sender)))
        
        (ok (get amount-funded funder-data))
    )
)

(define-public (close-expired-bond (bond-id uint))
    (let
        (
            (bond (unwrap! (map-get? impact-bonds bond-id) err-bond-not-found))
            (current-block stacks-block-height)
        )
        ;; Only creator or contract owner can close
        (asserts! (or (is-eq tx-sender (get creator bond)) (is-eq tx-sender contract-owner)) err-not-bond-creator)
        ;; Must be past both deadlines
        (asserts! (> current-block (get outcome-deadline bond)) err-bond-expired)
        
        (map-set impact-bonds bond-id (merge bond {
            status: "expired"
        }))
        (ok true)
    )
)

;; Read-only functions for impact bonds

(define-read-only (get-bond-details (bond-id uint))
    (map-get? impact-bonds bond-id)
)

(define-read-only (get-bond-funder-data (bond-id uint) (funder principal))
    (map-get? bond-funders {bond-id: bond-id, funder: funder})
)

(define-read-only (get-bond-outcome (bond-id uint))
    (map-get? bond-outcomes bond-id)
)

(define-read-only (get-last-bond-id)
    (var-get last-bond-id)
)

(define-read-only (calculate-potential-return (bond-id uint) (funding-amount uint))
    (match (map-get? impact-bonds bond-id)
        bond-data
        (let
            (
                (payout-rate (get payout-rate bond-data))
                (max-bonus (/ (* funding-amount payout-rate) u10000))
            )
            (ok {
                base-return: funding-amount,
                max-bonus: max-bonus,
                total-max-return: (+ funding-amount max-bonus)
            })
        )
        (err err-bond-not-found)
    )
)

