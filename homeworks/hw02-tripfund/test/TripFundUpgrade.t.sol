// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {TripFund} from "../src/TripFund.sol";
import {TripFundV2} from "../src/TripFundV2.sol";
import {MockToken} from "../src/MockToken.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Bonus integration tests with OpenZeppelin Upgrades validation enabled.
contract TripFundUpgradeTest is Test {
    event ContributedFor(address indexed payer, address indexed beneficiary, uint256 amount);

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant FRIEND = address(0xF12EAD);
    address internal constant ORGANIZER = address(0x0B6A);
    address internal constant PROXY_OWNER = address(0xAD0001);
    uint256 internal constant GOAL = 1_000;

    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    MockToken internal token;
    TripFund internal fund;
    address internal proxy;
    uint256 internal deadline;

    function setUp() public {
        token = new MockToken();
        token.mint(ALICE, 10_000);
        token.mint(BOB, 10_000);
        deadline = block.timestamp + 5 days;

        // Validated Transparent Proxy deployment (OpenZeppelin Contracts 5.x).
        proxy = Upgrades.deployTransparentProxy(
            "TripFund.sol:TripFund",
            PROXY_OWNER,
            abi.encodeCall(TripFund.initialize, (address(token), ORGANIZER, GOAL, deadline))
        );
        fund = TripFund(proxy);
    }

    function _pay(address payer, uint256 amount) internal {
        vm.startPrank(payer);
        token.approve(proxy, amount); // Approve PROXY, not implementation!
        fund.contribute(amount);
        vm.stopPrank();
    }

    function _upgrade() internal {
        // Upgrades CLI validates V2's safety and the V1 -> V2 storage layout.
        // tryCaller chooses the actual owner of the ProxyAdmin for the on-chain upgrade.
        Upgrades.upgradeProxy(proxy, "TripFundV2.sol:TripFundV2", "", PROXY_OWNER);
    }

    function test_V1Contribution_ValidatedUpgrade_StatePreserved_GiftAndRefund() public {
        _pay(ALICE, 200);
        _pay(BOB, 100);
        uint256 oldDeadline = fund.deadline();
        uint256 oldBalance = token.balanceOf(proxy);
        uint256 oldRaised = fund.totalRaised();
        address oldProxy = proxy;

        _upgrade(); // Before the deadline; proxy address does not change.
        TripFundV2 v2 = TripFundV2(proxy);
        assertEq(proxy, oldProxy);
        assertEq(address(v2.token()), address(token));
        assertEq(v2.organizer(), ORGANIZER);
        assertEq(v2.goal(), GOAL);
        assertEq(v2.deadline(), oldDeadline);
        assertEq(v2.contributions(ALICE), 200);
        assertEq(v2.contributions(BOB), 100);
        assertEq(v2.totalRaised(), oldRaised);
        assertEq(token.balanceOf(proxy), oldBalance);
        assertFalse(v2.withdrawn());

        // A V2 contribution can attribute refund rights to another beneficiary.
        vm.startPrank(ALICE);
        token.approve(proxy, 250);
        v2.contributeFor(FRIEND, 250);
        vm.stopPrank();
        assertEq(v2.contributions(FRIEND), 250);
        assertEq(v2.contributions(ALICE), 200);
        assertEq(token.balanceOf(FRIEND), 0);
        assertEq(token.balanceOf(ALICE), 9_550);

        // The old V1 contribute() still works after upgrading.
        _pay(BOB, 50);
        assertEq(v2.contributions(BOB), 150);
        assertEq(v2.totalRaised(), 600);
        assertEq(token.balanceOf(proxy), 600);

        vm.warp(deadline); // Goal missed; only beneficiaries can refund.
        vm.prank(ALICE);
        v2.refund();
        vm.prank(BOB);
        v2.refund();
        vm.prank(FRIEND);
        v2.refund();

        assertEq(token.balanceOf(FRIEND), 250);
        assertEq(token.balanceOf(ALICE), 9_750);
        assertEq(token.balanceOf(BOB), 10_000);
        assertEq(token.balanceOf(proxy), 0);
        assertEq(v2.contributions(FRIEND), 0);
        assertEq(v2.contributions(ALICE), 0);
        assertEq(v2.contributions(BOB), 0);
        assertEq(v2.totalRaised(), 600); // cumulative
    }

    function test_V2RejectsZeroBeneficiaryZeroAmountAndLateContributions() public {
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);

        vm.startPrank(ALICE);
        token.approve(proxy, 1_000);
        vm.expectRevert(TripFund.InvalidBeneficiary.selector);
        v2.contributeFor(address(0), 1);
        vm.expectRevert(TripFund.ZeroAmount.selector);
        v2.contributeFor(FRIEND, 0);
        vm.stopPrank();

        assertEq(v2.contributions(FRIEND), 0);
        assertEq(v2.totalRaised(), 0);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(proxy), 0);

        vm.warp(deadline);
        vm.prank(ALICE);
        vm.expectRevert(TripFund.FundingClosed.selector);
        v2.contributeFor(FRIEND, 1);
        assertEq(v2.totalRaised(), 0);
    }

    function test_V2RequiresRealPayersBalanceAndAllowance() public {
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);
        vm.prank(ALICE);
        vm.expectRevert();
        v2.contributeFor(FRIEND, 400);
        assertEq(v2.totalRaised(), 0);

        vm.startPrank(ALICE);
        token.approve(proxy, type(uint256).max);
        vm.expectRevert();
        v2.contributeFor(FRIEND, 10_001);
        vm.stopPrank();
        assertEq(v2.totalRaised(), 0);
        assertEq(v2.contributions(FRIEND), 0);
        assertEq(token.balanceOf(proxy), 0);
    }

    function test_V2ContributeForEventPayerBeneficiaryAndRepeatedPayments() public {
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);

        vm.startPrank(ALICE);
        token.approve(proxy, 500);
        vm.expectEmit(true, true, false, true, proxy);
        emit ContributedFor(ALICE, FRIEND, 120);
        v2.contributeFor(FRIEND, 120);
        v2.contributeFor(FRIEND, 80);
        vm.stopPrank();

        assertEq(v2.contributions(FRIEND), 200);
        assertEq(v2.contributions(ALICE), 0);
        assertEq(v2.totalRaised(), 200);
        assertEq(token.balanceOf(ALICE), 9_800);
        assertEq(token.balanceOf(FRIEND), 0);
        assertEq(token.balanceOf(proxy), 200);
        assertEq(token.allowance(ALICE, proxy), 300);

        vm.warp(deadline);
        vm.prank(ALICE);
        vm.expectRevert(TripFund.NothingToRefund.selector);
        v2.refund();
        vm.prank(FRIEND);
        v2.refund();
        assertEq(token.balanceOf(FRIEND), 200);
        assertEq(token.balanceOf(proxy), 0);
    }

    function test_V2ContributionAtDeadlineMinusOneAndAtDeadline() public {
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);
        vm.prank(ALICE);
        token.approve(proxy, 200);

        vm.warp(deadline - 1);
        vm.prank(ALICE);
        v2.contributeFor(FRIEND, 80);
        vm.warp(deadline);
        vm.prank(ALICE);
        vm.expectRevert(TripFund.FundingClosed.selector);
        v2.contributeFor(FRIEND, 120);

        assertEq(v2.contributions(FRIEND), 80);
        assertEq(v2.totalRaised(), 80);
        assertEq(token.balanceOf(proxy), 80);
        assertEq(token.balanceOf(ALICE), 9_920);
        assertEq(token.allowance(ALICE, proxy), 120);
    }

    function test_V2ExactGoalThroughGiftCanBeWithdrawnByOrganizerOnly() public {
        _pay(ALICE, 400);
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);

        vm.startPrank(BOB);
        token.approve(proxy, 600);
        v2.contributeFor(FRIEND, 600);
        vm.stopPrank();

        assertEq(v2.totalRaised(), GOAL);
        vm.warp(deadline);
        vm.prank(FRIEND);
        vm.expectRevert(TripFund.GoalReached.selector);
        v2.refund();
        vm.prank(BOB);
        vm.expectRevert(TripFund.NotOrganizer.selector);
        v2.withdraw();
        vm.prank(ORGANIZER);
        v2.withdraw();
        assertEq(token.balanceOf(ORGANIZER), GOAL);
        assertEq(token.balanceOf(proxy), 0);
        assertEq(v2.contributions(FRIEND), 600);
        assertEq(v2.totalRaised(), GOAL);
    }

    function test_V2FailedGiftDoesNotWriteAccountingOrTakeTokens() public {
        _upgrade();
        TripFundV2 v2 = TripFundV2(proxy);
        vm.startPrank(ALICE);
        token.approve(proxy, 100);
        vm.expectRevert();
        v2.contributeFor(FRIEND, 101);
        vm.stopPrank();

        assertEq(token.allowance(ALICE, proxy), 100);
        assertEq(token.balanceOf(ALICE), 10_000);
        assertEq(token.balanceOf(proxy), 0);
        assertEq(v2.contributions(FRIEND), 0);
        assertEq(v2.totalRaised(), 0);
    }

    function test_NonOwnerCannotUpgradeAndInitializersStayLocked() public {
        address admin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        assertTrue(admin != address(0));
        assertEq(ProxyAdmin(admin).owner(), PROXY_OWNER);

        TripFundV2 newImplementation = new TripFundV2();
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ALICE));
        ProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), address(newImplementation), "");

        // Proxy still runs V1: V2's selector is unavailable.
        vm.prank(ALICE);
        vm.expectRevert();
        TripFundV2(proxy).contributeFor(FRIEND, 1);

        _upgrade();
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        TripFundV2(proxy).initialize(address(token), ORGANIZER, GOAL, deadline);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        newImplementation.initialize(address(token), ORGANIZER, GOAL, deadline);
    }
}
