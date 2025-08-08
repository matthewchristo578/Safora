;; verification.clar
;; Clarity v2
;; Provides public read functions to verify product authenticity and history
;; Compares current data to original minting records
;; Outputs human-readable history for consumer-facing apps

;; Error codes
(define-constant ERR-INVALID-PRODUCT u300)
(define-constant ERR-NO-METADATA u301)
(define-constant ERR-NO-TRANSFER-HISTORY u302)
(define-constant ERR-INVALID-PRODUCT-ID u303)
(define-constant ERR-PRODUCT-REGISTRY-NOT-FOUND u304)
(define-constant ERR-TRANSFER-CUSTODY-NOT-FOUND u305)

;; Contract state
(define-data-var admin principal tx-sender)
(define-data-var product-registry principal 'SP000000000000000000002Q6VF78) ;; Placeholder for product-registry contract
(define-data-var transfer-custody principal 'SP000000000000000000002Q6VF78) ;; Placeholder for transfer-custody contract

;; Human-readable format for metadata
(define-map cached-metadata-strings
  { product-id: uint }
  (string-utf8 512)
)

;; Private helper: Check if product exists
(define-private (product-exists (product-id uint))
  (let
    (
      (registry (var-get product-registry))
      (owner-result (contract-call? registry get-product-owner product-id))
    )
    (is-ok owner-result)
  )
)

;; Private helper: Get product metadata
(define-private (get-product-metadata-internal (product-id uint))
  (let
    (
      (registry (var-get product-registry))
      (metadata-result (contract-call? registry get-product-metadata product-id))
    )
    (match metadata-result
      metadata (unwrap! metadata (err ERR-NO-METADATA))
      (err ERR-NO-METADATA)
    )
  )
)

;; Private helper: Format timestamp to human-readable string
(define-private (format-timestamp (timestamp uint))
  (let
    (
      (year (+ (/ timestamp u31536000) u1970)) ;; Assuming seconds since epoch
      (remainder (- timestamp (* (- year u1970) u31536000)))
      (month (+ (/ remainder u2592000) u1))
      (day (+ (/ (- remainder (* (- month u1) u2592000)) u86400) u1))
    )
    (concat (concat (concat (int-to-ascii year) "-") (int-to-ascii month)) (concat "-" (int-to-ascii day)))
  )
)

;; Private helper: Format metadata to human-readable string
(define-private (format-metadata (metadata { batch-id: (string-ascii 64), manufacturing-date: uint, origin: (string-ascii 128), manufacturer: principal, mint-timestamp: uint }))
  (let
    (
      (batch-id (get batch-id metadata))
      (manufacturing-date (format-timestamp (get manufacturing-date metadata)))
      (origin (get origin metadata))
      (manufacturer (get manufacturer metadata))
      (mint-timestamp (format-timestamp (get mint-timestamp metadata)))
    )
    (concat
      (concat
        (concat
          (concat
            (concat
              (concat
                (concat
                  (concat "Batch ID: " batch-id)
                  ", Manufacturing Date: ")
                manufacturing-date)
              ", Origin: ")
            origin)
          ", Manufacturer: ")
        (principal-to-string manufacturer))
      (concat ", Minted: " mint-timestamp))
  )
)

;; Admin: Set product registry contract
(define-public (set-product-registry (registry principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq registry 'SP000000000000000000002Q6VF78)) (err ERR-PRODUCT-REGISTRY-NOT-FOUND))
    (var-set product-registry registry)
    (ok true)
  )
)

;; Admin: Set transfer custody contract
(define-public (set-transfer-custody (custody principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq custody 'SP000000000000000000002Q6VF78)) (err ERR-TRANSFER-CUSTODY-NOT-FOUND))
    (var-set transfer-custody custody)
    (ok true)
  )
)

;; Read-only: Verify product authenticity
(define-read-only (verify-product-authenticity (product-id uint))
  (begin
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (product-exists product-id) (err ERR-INVALID-PRODUCT))
    (let
      (
        (metadata (get-product-metadata-internal product-id))
        (owner-result (contract-call? (var-get product-registry) get-product-owner product-id))
        (owner (unwrap! owner-result (err ERR-INVALID-PRODUCT)))
      )
      (ok {
        is-authentic: true,
        current-owner: owner,
        batch-id: (get batch-id metadata),
        manufacturing-date: (get manufacturing-date metadata),
        origin: (get origin metadata),
        manufacturer: (get manufacturer metadata),
        mint-timestamp: (get mint-timestamp metadata)
      })
    )
  )
)

;; Read-only: Get full product history
(define-read-only (get-product-history (product-id uint))
  (begin
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (asserts! (product-exists product-id) (err ERR-INVALID-PRODUCT))
    (let
      (
        (transfer-custody-contract (var-get transfer-custody))
        (transfer-count-result (contract-call? transfer-custody-contract get-transfer-count product-id))
        (transfer-count (unwrap! transfer-count-result (err ERR-NO-TRANSFER-HISTORY)))
        (metadata (get-product-metadata-internal product-id))
        (cached-string (map-get? cached-metadata-strings { product-id: product-id }))
      )
      (if (is-some cached-string)
        (ok (unwrap! cached-string (err ERR-NO-METADATA)))
        (let
          (
            (formatted-string (format-metadata metadata))
          )
          (map-set cached-metadata-strings { product-id: product-id } formatted-string)
          (ok formatted-string)
        )
      )
    )
  )
)

;; Read-only: Get transfer history
(define-read-only (get-transfer-history (product-id uint) (transfer-id uint))
  (begin
    (asserts! (> product-id u0) (err ERR-INVALID-PRODUCT-ID))
    (let
      (
        (transfer-custody-contract (var-get transfer-custody))
        (history-result (contract-call? transfer-custody-contract get-transfer-history product-id transfer-id))
      )
      (match history-result
        history (ok (concat
                      (concat
                        (concat
                          (concat
                            (concat "Transfer ID: " (int-to-ascii transfer-id))
                            ", From: ")
                          (principal-to-string (get sender history)))
                        (concat ", To: " (principal-to-string (get receiver history))))
                      (concat ", Timestamp: " (format-timestamp (get transfer-timestamp history))))
        )
        (err ERR-NO-TRANSFER-HISTORY)
      )
    )
  )
)

;; Read-only: Get product registry
(define-read-only (get-product-registry)
  (ok (var-get product-registry))
)

;; Read-only: Get transfer custody
(define-read-only (get-transfer-custody)
  (ok (var-get transfer-custody))
)