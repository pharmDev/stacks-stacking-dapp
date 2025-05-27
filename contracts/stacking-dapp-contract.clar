
;; stacking-dapp-contract
;; A decentralized staking application for Stacks blockchain

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-staked (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-minimum-not-met (err u105))
(define-constant err-staking-locked (err u106))
(define-constant err-not-staked (err u107))
(define-constant err-cooldown-period (err u108))
(define-constant err-pool-full (err u109))
(define-constant err-invalid-duration (err u110))

(define-constant min-staking-amount u100000000) ;; 100 STX minimum
(define-constant max-pool-size u1000000000000) ;; 1M STX max pool size
(define-constant reward-cycle-length u144) ;; ~1 day in blocks
(define-constant cooldown-period u72) ;; ~12 hours in blocks

;; data maps and vars
(define-data-var total-staked uint u0)
(define-data-var staking-enabled bool true)
(define-data-var current-cycle uint u0)
(define-data-var pool-rewards-per-cycle uint u50000000) ;; 50 STX per cycle

(define-map staker-info 
  { staker: principal } 
  {
    amount: uint,
    rewards-claimed: uint,
    unlock-height: uint,
    last-reward-cycle: uint,
    staking-duration: uint
  }
)

(define-map cycle-rewards 
  { cycle: uint } 
  { total-reward: uint }
)

(define-map staker-by-cycle
  { cycle: uint, staker: principal }
  { participated: bool }
)

;; private functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (calculate-reward (staker principal) (amount uint) (duration uint))
  (let (
    (base-reward (/ (* amount duration) u10000))
    (bonus (if (>= duration u6) (/ amount u100) u0))
  )
    (+ base-reward bonus)
  )
)

(define-private (get-current-reward-cycle)
  (let (
    (current-block-height block-height)
  )
    (/ current-block-height reward-cycle-length)
  )
)

(define-private (update-reward-cycle)
  (let (
    (new-cycle (get-current-reward-cycle))
  )
    (if (> new-cycle (var-get current-cycle))
      (begin
        (var-set current-cycle new-cycle)
        (map-set cycle-rewards { cycle: new-cycle } { total-reward: (var-get pool-rewards-per-cycle) })
        (ok true)
      )
      (ok false)
    )
  )
)

