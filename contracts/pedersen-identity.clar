;; pedersen-identity.clar
;; A decentralized identity management contract for prefetch-pedersen
;; Provides secure, sovereign identity verification and access management
;; with enhanced privacy and granular permission controls.

;; =============================
;; Constants / Error Codes
;; =============================

;; General errors
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-USER-ALREADY-REGISTERED (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-IDENTITY-PROVIDER-NOT-VERIFIED (err u103))

;; Identity errors
(define-constant ERR-IDENTITY-NOT-FOUND (err u200))
(define-constant ERR-IDENTITY-ALREADY-EXISTS (err u201))
(define-constant ERR-UNAUTHORIZED-IDENTITY-ACCESS (err u202))

;; Permission errors
(define-constant ERR-PERMISSION-ALREADY-GRANTED (err u300))
(define-constant ERR-PERMISSION-NOT-FOUND (err u301))
(define-constant ERR-PERMISSION-EXPIRED (err u302))

;; Role constants
(define-constant ROLE-USER u1)
(define-constant ROLE-PROVIDER u2)
(define-constant ROLE-ADMIN u3)

;; =============================
;; Data Maps and Variables
;; =============================

;; Contract administrator - initially set to contract deployer
(define-data-var contract-admin principal tx-sender)

;; User identity registry
(define-map user-identities principal 
  {
    role: uint,               ;; ROLE-USER or ROLE-PROVIDER
    is-active: bool,          ;; User account status
    verified: bool,           ;; Verification status
    name: (string-utf8 64),   ;; User's display name
    registration-time: uint   ;; Registration block height
  }
)

;; Identity access permissions
(define-map identity-permissions
  { identity-owner: principal, accessor: principal }
  {
    granted-at: uint,         ;; Permission grant timestamp
    expires-at: uint,         ;; Permission expiration
    access-level: uint,       ;; Permission granularity
    specific-attributes: (list 10 (string-utf8 50))  ;; Specific identity attributes
  }
)

;; Audit log for identity interactions
(define-map identity-audit-log
  uint  ;; Sequential log ID
  {
    identity-owner: principal,
    accessor: principal,
    action-type: (string-utf8 20),
    timestamp: uint,
    details: (string-utf8 100)
  }
)

;; Global audit log counter
(define-data-var identity-audit-counter uint u0)

;; =============================
;; Private Functions
;; =============================

;; Check if caller is a registered user
(define-private (is-registered-user (user principal))
  (match (map-get? user-identities user)
    user-data (and (is-eq (get role user-data) ROLE-USER) 
                   (get is-active user-data))
    false
  )
)

;; Check if caller is an authorized identity provider
(define-private (is-verified-provider (user principal))
  (match (map-get? user-identities user)
    user-data (and (is-eq (get role user-data) ROLE-PROVIDER) 
                   (get is-active user-data)
                   (get verified user-data))
    false
  )
)

;; Check if caller is contract administrator
(define-private (is-admin (user principal))
  (is-eq user (var-get contract-admin))
)

;; Create audit log entry
(define-private (log-identity-action 
  (identity-owner principal) 
  (accessor principal) 
  (action-type (string-utf8 20)) 
  (details (string-utf8 100)))
  
  (let ((log-id (+ (var-get identity-audit-counter) u1)))
    (var-set identity-audit-counter log-id)
    
    (map-set identity-audit-log log-id
      {
        identity-owner: identity-owner,
        accessor: accessor,
        action-type: action-type,
        timestamp: block-height,
        details: details
      }
    )
    log-id
  )
)

;; =============================
;; Read-Only Functions
;; =============================

;; Get user identity information
(define-read-only (get-identity-info (user principal))
  (map-get? user-identities user)
)

;; Check access permissions for an identity
(define-read-only (check-identity-access 
  (identity-owner principal) 
  (accessor principal))
  (match (map-get? identity-permissions 
           { identity-owner: identity-owner, accessor: accessor })
    permission-data {
      has-access: (if (> (get expires-at permission-data) u0)
                     (< block-height (get expires-at permission-data))
                     true),
      access-level: (get access-level permission-data),
      specific-attributes: (get specific-attributes permission-data)
    }
    { has-access: false, access-level: u0, specific-attributes: (list) }
  )
)

;; =============================
;; Public Functions
;; =============================

;; Change contract administrator
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)
  )
)