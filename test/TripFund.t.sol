// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TripFund} from "../src/TripFund.sol";
import {MockToken} from "../src/MockToken.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TripFundTest is Test {
    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Withdrawn(address indexed organizer, uint256 amount);

    uint256 internal constant GOAL = 1_000;
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant CAROL = address(0xCA001);
    address internal constant ORGANIZER = address(0x0B6A);
    address internal constant PROXY_OWNER = address(0xAD0001);

    MockToken internal token;
    TripFund internal implementation;
    TripFund internal fund;
    uint256 internal deadline;

    function setUp() public {
        token = new MockToken();
        token.mint(ALICE, 10_000);
        token.mint(BOB, 10_000);
        token.mint(CAROL, 10_000);
        implementation = new TripFund();
        deadline = block.timestamp + 7 days;
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            PROXY_OWNER,
            abi.encodeCall(TripFund.initialize, (address(token), ORGANIZER, GOAL, deadline))
        );
        fund = TripFund(address(proxy));
    }

    function _contribute(address who, uint256 amount) internal {
        vm.startPrank(who);
        token.approve(address(fund), amount);
        fund.contribute(amount);
        vm.stopPrank();
    }

    function _reachDeadline() internal {
        vm.warp(deadline);
    }

    function test_InitializationAndImmutableConfigurationByInterface() public view {
        assertEq(address(fund.token()), address(token));
        assertEq(fund.organizer(), ORGANIZER);
        assertEq(fund.goal(), GOAL);
        assertEq(fund.deadline(), deadline);
        assertEq(fund.totalRaised(), 0);
        assertFalse(fund.withdrawn());
    }

    function test_RejectsInvalidInitializationParameters() public {
        _expectInvalidInitialization(address(0), ORGANIZER, GOAL, deadline, TripFund.InvalidToken.selector);
        _expectInvalidInitialization(address(token), address(0), GOAL, deadline, TripFund.InvalidOrganizer.selector);
        _expectInvalidInitialization(address(token), ORGANIZER, 0, deadline, TripFund.InvalidGoal.selector);
        _expectInvalidInitialization(address(token), ORGANIZER, GOAL, block.timestamp, TripFund.InvalidDeadline.selector);
        _expectInvalidInitialization(address(token), ORGANIZER, GOAL, block.timestamp - 1, TripFund.InvalidDeadline.selector);
    }

    function _expectInvalidInitialization(
        address token_, address organizer_, uint256 goal_, uint256 deadline_, bytes4 expectedError
    ) internal {
        vm.expectRevert(expectedError);
        new TransparentUpgradeableProxy(
            address(implementation),
            PROXY_OWNER,
            abi.encodeCall(TripFund.initialize, (token_, organizer_, goal_, deadline_))
        );
    }

    function test_CannotReinitializeProxyOrImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        fund.initialize(address(token), ORGANIZER, GOAL, deadline);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(address(token), ORGANIZER, GOAL, deadline);
    }

    function test_TwoContributorsRepeatedPaymentsAndBalances() public {
        _contribute(ALICE, 120);
        _contribute(BOB, 250);
        _contribute(ALICE, 80);

        assertEq(fund.contributions(ALICE), 200);
        assertEq(fund.contributions(BOB), 250);
        assertEq(fund.totalRaised(), 450);
        assertEq(token.balanceOf(ALICE), 9_800);
        assertEq(token.balanceOf(BOB), 9_750);
        assertEq(token.balanceOf(address(fund)), 450);
    }

    function test_RejectsZeroContributionWithoutChangingAccounting() public {
        vm.prank(ALICE);
        vm.expectRevert(TripFund.ZeroAmount.selector);
        fund.contribute(0);
        assertEq(fund.totalRaised(), 0);
        assertEq(fund.contributions(ALICE), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
    }

    function test_InsufficientAllowanceRevertsEverything() public {
        vm.startPrank(ALICE);
        token.approve(address(fund), 99);
        vm.expectRevert();
        fund.contribute(100);
        vm.stopPrank();

        assertEq(fund.contributions(ALICE), 0);
        assertEq(fund.totalRaised(), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(token.allowance(ALICE, address(fund)), 99);
    }

    function test_NoAllowanceRevertsEverything() public {
        vm.prank(ALICE);
        vm.expectRevert();
        fund.contribute(123);
        assertEq(fund.contributions(ALICE), 0);
        assertEq(fund.totalRaised(), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
    }

    function test_InsufficientTokenBalanceRevertsEverything() public {
        vm.startPrank(ALICE);
        token.approve(address(fund), type(uint256).max);
        vm.expectRevert();
        fund.contribute(10_001);
        vm.stopPrank();

        assertEq(fund.contributions(ALICE), 0);
        assertEq(fund.totalRaised(), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
    }

    function test_DeadlineMinusOneSecondWorks_ExactDeadlineDoesNot() public {
        vm.warp(deadline - 1);
        _contribute(ALICE, 40);
        assertEq(fund.totalRaised(), 40);

        vm.warp(deadline);
        vm.startPrank(BOB);
        token.approve(address(fund), 100);
        vm.expectRevert(TripFund.FundingClosed.selector);
        fund.contribute(100);
        vm.stopPrank();

        assertEq(fund.totalRaised(), 40);
        assertEq(fund.contributions(BOB), 0);
        assertEq(token.balanceOf(BOB), 10_000);
        assertEq(token.balanceOf(address(fund)), 40);
    }

    function test_CannotSettleEarlyEvenWhenGoalMet() public {
        _contribute(ALICE, GOAL);

        vm.prank(ORGANIZER);
        vm.expectRevert(TripFund.FundingStillOpen.selector);
        fund.withdraw();

        vm.prank(ALICE);
        vm.expectRevert(TripFund.FundingStillOpen.selector);
        fund.refund();

        assertEq(fund.totalRaised(), GOAL);
        assertEq(fund.contributions(ALICE), GOAL);
        assertEq(token.balanceOf(address(fund)), GOAL);
    }

    function test_ExactGoalAllowsOnlyOrganizerToWithdrawOnce() public {
        _contribute(ALICE, 600);
        _contribute(BOB, 400);
        _reachDeadline();

        vm.prank(ALICE);
        vm.expectRevert(TripFund.NotOrganizer.selector);
        fund.withdraw();

        vm.prank(BOB);
        vm.expectRevert(TripFund.GoalReached.selector);
        fund.refund();

        vm.prank(ORGANIZER);
        fund.withdraw();
        assertTrue(fund.withdrawn());
        assertEq(token.balanceOf(ORGANIZER), GOAL);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), GOAL); // Lifetime counter, not current funds.
        assertEq(fund.contributions(ALICE), 600);

        vm.prank(ORGANIZER);
        vm.expectRevert(TripFund.AlreadyWithdrawn.selector);
        fund.withdraw();
    }

    function test_OverGoalWithdrawsFullAccountedAmount() public {
        _contribute(ALICE, 800);
        _contribute(BOB, 350);
        _reachDeadline();
        vm.prank(ORGANIZER);
        fund.withdraw();
        assertEq(token.balanceOf(ORGANIZER), 1_150);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), 1_150);
    }

    function test_FailedCampaignIndependentFullRefundsAndWrongOutcome() public {
        _contribute(ALICE, 320);
        _contribute(BOB, 180);
        _reachDeadline();

        vm.prank(ORGANIZER);
        vm.expectRevert(TripFund.GoalNotReached.selector);
        fund.withdraw();

        vm.prank(CAROL);
        vm.expectRevert(TripFund.NothingToRefund.selector);
        fund.refund();

        vm.prank(BOB);
        fund.refund();
        assertEq(fund.contributions(BOB), 0);
        assertEq(fund.contributions(ALICE), 320);
        assertEq(token.balanceOf(BOB), 10_000);
        assertEq(token.balanceOf(address(fund)), 320);

        vm.prank(BOB);
        vm.expectRevert(TripFund.NothingToRefund.selector);
        fund.refund();

        vm.prank(ALICE);
        fund.refund();
        assertEq(fund.contributions(ALICE), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), 500); // Stays cumulative after refunds.
    }

    function test_DirectTransfersIgnoredAndRemainAfterSuccessfulPayout() public {
        _contribute(ALICE, GOAL);
        vm.prank(CAROL);
        token.transfer(address(fund), 77);
        assertEq(fund.totalRaised(), GOAL);
        assertEq(fund.contributions(CAROL), 0);
        assertEq(token.balanceOf(address(fund)), 1_077);

        _reachDeadline();
        vm.prank(ORGANIZER);
        fund.withdraw();
        assertEq(token.balanceOf(ORGANIZER), GOAL);
        assertEq(token.balanceOf(address(fund)), 77);
        assertEq(fund.totalRaised(), GOAL);
    }

    function test_DirectTransfersIgnoredAndRemainAfterFailedRefunds() public {
        _contribute(ALICE, 250);
        _contribute(BOB, 125);
        vm.prank(CAROL);
        token.transfer(address(fund), 77);
        assertEq(fund.totalRaised(), 375);

        _reachDeadline();
        vm.prank(ALICE);
        fund.refund();
        vm.prank(BOB);
        fund.refund();
        assertEq(token.balanceOf(address(fund)), 77);
        assertEq(fund.totalRaised(), 375);
    }

    function test_FailedPayoutTransferRollsBackWithdrawnFlag() public {
        _contribute(ALICE, GOAL);
        // Simulate an external loss of 1 unit using a Foundry prank, so payout cannot complete.
        vm.prank(address(fund));
        token.transfer(CAROL, 1);
        _reachDeadline();

        vm.prank(ORGANIZER);
        vm.expectRevert();
        fund.withdraw();
        assertFalse(fund.withdrawn());
        assertEq(fund.totalRaised(), GOAL);
        assertEq(fund.contributions(ALICE), GOAL);
        assertEq(token.balanceOf(ORGANIZER), 0);
        assertEq(token.balanceOf(address(fund)), GOAL - 1);
    }

    function test_FailedPayoutTransferRollsBackRefundZeroing() public {
        _contribute(ALICE, 100);
        vm.prank(address(fund));
        token.transfer(CAROL, 1);
        _reachDeadline();

        vm.prank(ALICE);
        vm.expectRevert();
        fund.refund();
        assertEq(fund.contributions(ALICE), 100);
        assertEq(fund.totalRaised(), 100);
        assertEq(token.balanceOf(ALICE), 9_900);
        assertEq(token.balanceOf(address(fund)), 99);
    }

    function test_ApproveMustTargetProxyNotImplementation() public {
        vm.startPrank(ALICE);
        token.approve(address(implementation), 150);
        vm.expectRevert();
        fund.contribute(150);
        vm.stopPrank();

        assertEq(token.allowance(ALICE, address(implementation)), 150);
        assertEq(token.allowance(ALICE, address(fund)), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.contributions(ALICE), 0);
        assertEq(fund.totalRaised(), 0);
    }

    function test_ContributionAndWithdrawEvents() public {
        vm.prank(ALICE);
        token.approve(address(fund), GOAL);

        vm.expectEmit(true, false, false, true, address(fund));
        emit Contributed(ALICE, GOAL);
        vm.prank(ALICE);
        fund.contribute(GOAL);

        _reachDeadline();
        vm.expectEmit(true, false, false, true, address(fund));
        emit Withdrawn(ORGANIZER, GOAL);
        vm.prank(ORGANIZER);
        fund.withdraw();
    }

    function test_RefundEventAndZeroedContribution() public {
        _contribute(ALICE, 210);
        _reachDeadline();

        vm.expectEmit(true, false, false, true, address(fund));
        emit Refunded(ALICE, 210);
        vm.prank(ALICE);
        fund.refund();

        assertEq(fund.contributions(ALICE), 0);
        assertEq(fund.totalRaised(), 210);
        assertEq(token.balanceOf(ALICE), 10_000);
    }

    function test_FailedContributionRetainsApprovedAllowanceAndBalances() public {
        vm.startPrank(ALICE);
        token.approve(address(fund), 200);
        vm.expectRevert();
        fund.contribute(201);
        vm.stopPrank();

        assertEq(token.allowance(ALICE, address(fund)), 200);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(address(fund)), 0);
        assertEq(fund.totalRaised(), 0);
        assertEq(fund.contributions(ALICE), 0);
    }

    function testFuzz_RepeatedContributionsAccumulate(uint96 a, uint96 b) public {
        uint256 first = bound(uint256(a), 1, 1_000);
        uint256 second = bound(uint256(b), 1, 1_000);
        _contribute(ALICE, first);
        _contribute(ALICE, second);
        assertEq(fund.totalRaised(), first + second);
        assertEq(fund.contributions(ALICE), first + second);
        assertEq(token.balanceOf(address(fund)), first + second);
    }
}
