;; transfer-custody.clar
;; Clarity v2
;; Manages transfer of product NFTs between supply chain participants
;; Requires confirmation from both sender and receiver
;; Updates product ownership on-chain with full audit trail

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u200)
(define-constant ERR-INVALID-PRODUCT u201)
(define-constant ERR-NOT-OWNER u202)
(define-constant ERR-ZERO-ADDRESS u203)
(define-constant ERR-PAUSED u204)
(define-constant ERR-TRANSFER-PENDING u205)
(define-constant ERR-NO-PENDING-TRANSFER u206)
(define-constant ERR-INVALID-RECEIVER u207)
(define-constant ERR-PRODUCT-REGISTRY-NOT-FOUND u208)
(define-constant ERR-INVALID-PRODUCT-ID u209)

;; Contract state
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var product-registry principal 'SP000000000000000000002Q6VF78) ;; Placeholder for product-registry contract

;; Pending transfers
(define-map pending-transfers
  { product-id: uint }
  {
    sender: principal,
    receiver: principal,
    initiated-at: uint
  }
)

;; Transfer history
(define-map transfer-history
  { product-id: uint, transfer-id: uint }
  {
    sender: principal,
    receiver: principal,
    transfer-timestamp: uint
  }
)

;; Track transfer count per product
(define-map transfer-count
  { product-id: uint }
  uint
)

;; Private helper: Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Private helper: Ensure contract is not paused
(define-private (ensure-not-paused)
  (asserts! (not (var-get paused)) (err ERR-PAUSED))
)

;; Private helper: Check if product exists in product-registry
(define-private (product-exists (product-id uint))
  (let
    (
      (registry (var-get product-registry))
      (owner-result (contract-call? registry get-product-owner product-id))
    )
    (is-ok owner-result)
  )
)

;; Private helper: Check if caller is product owner
(define-private (is-product-owner (product-id uint) (caller principal))
  (let
    (
      (registry (var-get product-registry))
      (owner-result (contract-call? registry get-product-owner product-id))
    )
    (match owner-result
      owner (is-eq (unwrap! owner (err ERR-INVALID-PRODUCT)) caller)
      (err ERR-INVALID-PRODUCT)
    )
  )
)

;; Admin: Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq new-admin 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Admin: Pause/unpause contract
(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (var-set paused pause)
    (ok pause)
  )
)

;; Admin: Set product registry contract
(define-public (set-product-registry (registry principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq registry 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (var-set product-registry registry)
    (ok true)
  )
)

;; Initiate transfer
(define-public (initiate-transfer (product-id uint) (receiver principal))
  (begin
    (ensure-not-paused)
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (product-exists product-id) (err ERR-INVALID-PRODUCT))
    (asserts! (is-product-owner product-id tx-sender) (err ERR-NOT-OWNER))
    (asserts! (not (is-eq receiver 'SP000000000000000000002Q6VF78)) (err ERR-ZERO-ADDRESS))
    (asserts! (is-none (map-get? pending-transfers { product-id: product-id })) (err ERR-TRANSFER-PENDING))
    (map-set pending-transfers
      { product-id: product-id }
      {
        sender: tx-sender,
        receiver: receiver,
        initiated-at: block-height
      }
    )
    (ok true)
  )
)

;; Confirm transfer as receiver
(define-public (confirm-transfer (product-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (product-exists product-id) (err ERR-INVALID-PRODUCT))
    (let
      (
        (transfer (unwrap! (map-get? pending-transfers { product-id: product-id }) (err ERR-NO-PENDING-TRANSFER)))
        (receiver (get receiver transfer))
        (sender (get sender transfer))
      )
      (asserts! (is-eq tx-sender receiver) (err ERR-INVALID-RECEIVER))
      (try! (contract-call? (var-get product-registry) nft-transfer? product-nft product-id sender receiver))
      (let
        (
          (current-count (default-to u0 (map-get? transfer-count { product-id: product-id })))
          (new-count (+ current-count u1))
        )
        (map-set transfer-history
          { product-id: product-id, transfer-id: new-count }
          {
            sender: sender,
            receiver: receiver,
            transfer-timestamp: block-height
          }
        )
        (map-set transfer-count { product-id: product-id } new-count)
        (map-delete pending-transfers { product-id: product-id })
        (ok new-count)
      )
    )
  )
)

;; Cancel transfer
(define-public (cancel-transfer (product-id uint))
  (begin
    (ensure-not-paused)
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (let
      (
        (transfer (unwrap! (map-get? pending-transfers { product-id: product-id }) (err ERR-NO-PENDING-TRANSFER)))
        (sender (get sender transfer))
      )
      (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
      (map-delete pending-transfers { product-id: product-id })
      (ok true)
    )
  )
)

;; Read-only: Get pending transfer
(define-read-only (get-pending-transfer (product-id uint))
  (ok (map-get? pending-transfers { product-id: product-id }))
)

;; Read-only: Get transfer history
(define-read-only (get-transfer-history (product-id uint) (transfer-id uint))
  (ok (map-get? transfer-history { product-id: product-id, transfer-id: transfer-id }))
)

;; Read-only: Get transfer count
(define-read-only (get-transfer-count (product-id uint))
  (ok (default-to u0 (map-get? transfer-count { product-id: product-id })))
)

;; Read-only: Get admin
(define-read-only (get-admin)
  (ok (var-get admin))
)

;; Read-only: Check if paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Read-only: Get product registry
(define-read-only (get-product-registry)
  (ok (var-get product-registry))
)