;; Liquidity Pool Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-pool-empty (err u103))
(define-constant err-slippage-too-high (err u104))
(define-constant err-invalid-token (err u105))
(define-constant max-iterations u32) ;; For sqrt calculation

;; Define data vars for token identifiers
(define-data-var token-a-id (string-ascii 32) "token-a")
(define-data-var token-b-id (string-ascii 32) "token-b")
(define-data-var pool-token-id (string-ascii 32) "pool-token")

;; Define token maps instead of fungible tokens
(define-map token-a-balances principal uint)
(define-map token-b-balances principal uint)
(define-map pool-token-balances principal uint)

;; Define data variables
(define-data-var total-liquidity uint u0)
(define-data-var fee-percentage uint u30) ;; 0.3% fee represented as 30/10000

;; Helper functions

(define-private (min (a uint) (b uint))
  (if (<= a b) a b))

;; Non-recursive square root implementation using binary search
(define-private (sqrt (y uint))
  (let
    (
      (n (+ u1 (/ y u2)))  ;; Initial guess
      (n2 (* n n))         ;; Square of guess
    )
    (if (>= n2 y)
      (if (> n2 y)
        (if (> n u1)
          (- n u1)
          u1)
        n)
      (if (> y (* (+ n u1) (+ n u1)))
        (+ n u1)
        n))))

;; Fixed token balance helper functions
(define-private (get-token-balance (token-map (string-ascii 1)) (who principal))
  (if (is-eq token-map "a")
      (default-to u0 (map-get? token-a-balances who))
      (if (is-eq token-map "b")
          (default-to u0 (map-get? token-b-balances who))
          (default-to u0 (map-get? pool-token-balances who)))))

(define-private (set-token-balance (token-map (string-ascii 1)) (who principal) (amount uint))
  (if (is-eq token-map "a")
      (map-set token-a-balances who amount)
      (if (is-eq token-map "b")
          (map-set token-b-balances who amount)
          (map-set pool-token-balances who amount))))

;; Read-only functions

(define-read-only (get-balance (token (string-ascii 1)) (who principal))
  (if (is-eq token "a")
      (ok (get-token-balance "a" who))
      (if (is-eq token "b")
          (ok (get-token-balance "b" who))
          (if (is-eq token "pool")
              (ok (get-token-balance "p" who))
              err-invalid-token))))

(define-read-only (get-reserves)
  {
    reserve-a: (get-token-balance "a" (as-contract tx-sender)),
    reserve-b: (get-token-balance "b" (as-contract tx-sender)),
    total-liquidity: (var-get total-liquidity)
  })

(define-read-only (calculate-tokens-to-add (amount-a uint) (amount-b uint))
  (let (
    (reserves (get-reserves))
    (total-a (get reserve-a reserves))
    (total-b (get reserve-b reserves))
    (liquidity (get total-liquidity reserves))
  )
    (asserts! (and (> amount-a u0) (> amount-b u0)) err-invalid-amount)
    (ok (if (is-eq liquidity u0)
        {
          liquidity-minted: (sqrt (* amount-a amount-b)),
          amount-a: amount-a,
          amount-b: amount-b
        }
        (let (
          (liquidity-a (/ (* amount-a liquidity) total-a))
          (liquidity-b (/ (* amount-b liquidity) total-b))
          (min-liquidity (min liquidity-a liquidity-b))
        )
          {
            liquidity-minted: min-liquidity,
            amount-a: (/ (* amount-a min-liquidity) liquidity-a),
            amount-b: (/ (* amount-b min-liquidity) liquidity-b)
          })))))

(define-read-only (calculate-tokens-to-remove (amount-pool uint))
  (let (
    (reserves (get-reserves))
    (total-a (get reserve-a reserves))
    (total-b (get reserve-b reserves))
    (liquidity (get total-liquidity reserves))
  )
    (asserts! (> amount-pool u0) err-invalid-amount)
    (asserts! (>= liquidity amount-pool) err-insufficient-balance)
    (ok {
      amount-a: (/ (* amount-pool total-a) liquidity),
      amount-b: (/ (* amount-pool total-b) liquidity)
    })))

(define-read-only (get-swap-amount (token-in (string-ascii 1)) (amount-in uint))
  (let (
    (reserves (get-reserves))
    (reserve-in (if (is-eq token-in "a") 
                    (get reserve-a reserves)
                    (get reserve-b reserves)))
    (reserve-out (if (is-eq token-in "a")
                     (get reserve-b reserves)
                     (get reserve-a reserves)))
  )
    (asserts! (> amount-in u0) err-invalid-amount)
    (asserts! (> reserve-in u0) err-pool-empty)
    (asserts! (> reserve-out u0) err-pool-empty)
    (let (
      (amount-in-with-fee (* amount-in (- u10000 (var-get fee-percentage))))
      (numerator (* amount-in-with-fee reserve-out))
      (denominator (+ (* reserve-in u10000) amount-in-with-fee))
    )
      (ok (/ numerator denominator)))))

;; Private token transfer functions
(define-private (transfer-token (token-id (string-ascii 1)) (from principal) (to principal) (amount uint))
  (let (
    (from-balance (get-token-balance token-id from))
    (to-balance (get-token-balance token-id to))
  )
    (asserts! (>= from-balance amount) err-insufficient-balance)
    (set-token-balance token-id from (- from-balance amount))
    (set-token-balance token-id to (+ to-balance amount))
    (ok true)))

;; Public functions

(define-public (add-liquidity (amount-a uint) (amount-b uint) (min-pool-tokens uint))
  (let (
    (sender tx-sender)
    (calc (try! (calculate-tokens-to-add amount-a amount-b)))
    (liquidity-minted (get liquidity-minted calc))
    (actual-a (get amount-a calc))
    (actual-b (get amount-b calc))
  )
    ;; Check minimum liquidity
    (asserts! (>= liquidity-minted min-pool-tokens) err-slippage-too-high)
    
    ;; Check balances
    (asserts! (>= (get-token-balance "a" sender) actual-a) err-insufficient-balance)
    (asserts! (>= (get-token-balance "b" sender) actual-b) err-insufficient-balance)
    
    ;; Transfer tokens and mint pool tokens atomically
    (try! (transfer-token "a" sender (as-contract tx-sender) actual-a))
    (try! (transfer-token "b" sender (as-contract tx-sender) actual-b))
    (var-set total-liquidity (+ (var-get total-liquidity) liquidity-minted))
    (set-token-balance "p" sender 
                       (+ (get-token-balance "p" sender) liquidity-minted))
    (ok true)))

(define-public (remove-liquidity (amount-pool uint) (min-a uint) (min-b uint))
  (let (
    (sender tx-sender)
    (calc (try! (calculate-tokens-to-remove amount-pool)))
    (amount-a (get amount-a calc))
    (amount-b (get amount-b calc))
  )
    (asserts! (and (>= amount-a min-a) (>= amount-b min-b)) err-slippage-too-high)
    (asserts! (>= (get-token-balance "p" sender) amount-pool) err-insufficient-balance)
    
    (set-token-balance "p" sender 
                       (- (get-token-balance "p" sender) amount-pool))
    (var-set total-liquidity (- (var-get total-liquidity) amount-pool))
    (try! (as-contract (transfer-token "a" tx-sender sender amount-a)))
    (try! (as-contract (transfer-token "b" tx-sender sender amount-b)))
    (ok true)))

(define-public (swap (token-in (string-ascii 1)) (amount-in uint) (min-amount-out uint))
  (let (
    (sender tx-sender)
    (amount-out (try! (get-swap-amount token-in amount-in)))
    (token-out (if (is-eq token-in "a") "b" "a"))
  )
    (asserts! (>= amount-out min-amount-out) err-slippage-too-high)
    (asserts! (or (is-eq token-in "a") (is-eq token-in "b")) err-invalid-token)
    
    ;; Check balance
    (asserts! (>= (get-token-balance token-in sender) amount-in)
              err-insufficient-balance)
    
    ;; Execute swap atomically
    (try! (transfer-token token-in sender (as-contract tx-sender) amount-in))
    (try! (as-contract (transfer-token token-out tx-sender sender amount-out)))
    (ok true)))

(define-public (collect-fees)
  (let (
    (reserves (get-reserves))
    (total-a (get reserve-a reserves))
    (total-b (get reserve-b reserves))
    (fee-a (/ (* total-a (var-get fee-percentage)) u10000))
    (fee-b (/ (* total-b (var-get fee-percentage)) u10000))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (try! (as-contract (transfer-token "a" tx-sender contract-owner fee-a)))
    (try! (as-contract (transfer-token "b" tx-sender contract-owner fee-b)))
    (ok true)))