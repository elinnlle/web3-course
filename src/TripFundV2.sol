// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TripFund} from "./TripFund.sol";

/// @custom:oz-upgrades-from TripFund
contract TripFundV2 is TripFund {
    event ContributedFor(address indexed payer, address indexed beneficiary, uint256 amount);

    /// @notice Pays with msg.sender's tokens; attributes the contribution to beneficiary.
    /// @dev V2 adds no storage variables and preserves the entire V1 layout.
    function contributeFor(address beneficiary, uint256 amount) external nonReentrant {
        _contributeFrom(msg.sender, beneficiary, amount);
        emit ContributedFor(msg.sender, beneficiary, amount);
    }
}
