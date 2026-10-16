// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title TripFund - a one-token crowdfunding contract for a team trip.
/// @notice Deploy through an initialized TransparentUpgradeableProxy (OZ 5.x).
contract TripFund is Initializable {
    using SafeERC20 for IERC20;

    error InvalidToken();
    error InvalidOrganizer();
    error InvalidGoal();
    error InvalidDeadline();
    error ZeroAmount();
    error InvalidBeneficiary();
    error FundingClosed();
    error FundingStillOpen();
    error GoalNotReached();
    error GoalReached();
    error NotOrganizer();
    error AlreadyWithdrawn();
    error NothingToRefund();
    error ReentrantCall();

    IERC20 public token;
    address public organizer;
    uint256 public goal;
    uint256 public deadline;

    mapping(address => uint256) public contributions;
    uint256 public totalRaised;
    bool public withdrawn;
    uint256 private _entered; // Reentrancy guard, part of V1 storage layout.

    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed organizer, uint256 amount);

    modifier nonReentrant() {
        if (_entered != 0) revert ReentrantCall();
        _entered = 1;
        _;
        _entered = 0;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Implementation storage must never be initializable directly.
        _disableInitializers();
    }

    function initialize(address token_, address organizer_, uint256 goal_, uint256 deadline_) external initializer {
        if (token_ == address(0)) revert InvalidToken();
        if (organizer_ == address(0)) revert InvalidOrganizer();
        if (goal_ == 0) revert InvalidGoal();
        if (deadline_ <= block.timestamp) revert InvalidDeadline();

        token = IERC20(token_);
        organizer = organizer_;
        goal = goal_;
        deadline = deadline_;
    }

    /// @dev The caller approves *the proxy address* in the ERC-20 first.
    function contribute(uint256 amount) external virtual nonReentrant {
        _contributeFrom(msg.sender, msg.sender, amount);
    }

    /// @dev Shared V1/V2 accounting; updates are completed before token interaction.
    ///      A failed SafeERC20 transfer reverts the entire transaction, including accounting.
    function _contributeFrom(address payer, address beneficiary, uint256 amount) internal {
        if (beneficiary == address(0)) revert InvalidBeneficiary();
        if (amount == 0) revert ZeroAmount();
        if (block.timestamp >= deadline) revert FundingClosed();

        contributions[beneficiary] += amount;
        totalRaised += amount;
        token.safeTransferFrom(payer, address(this), amount);

        emit Contributed(beneficiary, amount);
    }

    /// @notice Pay exactly the *accounted* amount, leaving any direct transfers untouched.
    function withdraw() external nonReentrant {
        if (block.timestamp < deadline) revert FundingStillOpen();
        if (totalRaised < goal) revert GoalNotReached();
        if (msg.sender != organizer) revert NotOrganizer();
        if (withdrawn) revert AlreadyWithdrawn();

        withdrawn = true;
        token.safeTransfer(organizer, totalRaised);
        emit Withdrawn(organizer, totalRaised);
    }

    /// @notice Refund this address's whole contribution after an unsuccessful campaign.
    function refund() external nonReentrant {
        if (block.timestamp < deadline) revert FundingStillOpen();
        if (totalRaised >= goal) revert GoalReached();
        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();

        contributions[msg.sender] = 0;
        // totalRaised deliberately stays cumulative, even after refunds.
        token.safeTransfer(msg.sender, amount);
        emit Refunded(msg.sender, amount);
    }
}
