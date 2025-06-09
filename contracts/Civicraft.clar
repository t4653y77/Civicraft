
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

(define-data-var last-token-id uint u0)
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