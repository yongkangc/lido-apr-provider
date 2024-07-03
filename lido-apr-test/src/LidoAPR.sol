// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IstETH {
    function getTotalPooledEther() external view returns (uint256);
    function getTotalShares() external view returns (uint256);
}

contract LidoAPR is Ownable {
    // Address of the stETH contract
    address constant STETH_ADDR = 0xae7ab96520de3a18e5e111b5eaab095312d7fe84;

    // State variables
    uint256 public yesterdayShareRate;
    uint256 public lastUpdateTime;

    error CooldownPeriodNotElapsed(uint256 currentTimestamp, uint256 nextAllowedUpdateTimestamp);

    event ShareRateUpdated(uint256 newShareRate, uint256 updateTime);

    constructor() {
        // Initialize state variables in the constructor with values from the stETH contract
        uint256 initialPooledEther = IstETH(STETH_ADDR).getTotalPooledEther();
        uint256 initialShares = IstETH(STETH_ADDR).getTotalShares();
        yesterdayShareRate = (initialPooledEther * 1e27) / initialShares;
        lastUpdateTime = block.timestamp;
    }
    
    // External view function to get the Lido base rate
    function getLidoBaseRate() external view returns (uint256) {
        // Query today's shares and pooled ether
        uint256 todayPooledEther = IstETH(STETH_ADDR).getTotalPooledEther();
        uint256 todayShares = IstETH(STETH_ADDR).getTotalShares();
        uint256 todayShareRate = (todayPooledEther * 1e27) / todayShares;

        // Calculate elapsed time
        uint256 elapsedTime = block.timestamp - lastUpdateTime;
        uint256 secondsInYear = 31536000; // 365 days

        // Calculate APR
        uint256 apr = ((secondsInYear * (todayShareRate - yesterdayShareRate) * 1e27) / yesterdayShareRate) / elapsedTime;

        return apr;
    }

    // Function to update the share rate and last update time
    // This function is restricted to the owner
    function updateShareRate() external onlyOwner {
        uint256 currentTimestamp = block.timestamp;
        uint256 nextAllowedUpdateTimestamp = lastUpdateTime + 24 hours;

        if (currentTimestamp <= nextAllowedUpdateTimestamp) {
            revert CooldownPeriodNotElapsed(currentTimestamp, nextAllowedUpdateTimestamp);
        }

        uint256 todayPooledEther = IstETH(STETH_ADDR).getTotalPooledEther();
        uint256 todayShares = IstETH(STETH_ADDR).getTotalShares();
        yesterdayShareRate = (todayPooledEther * 1e27) / todayShares;
        lastUpdateTime = block.timestamp;

        emit ShareRateUpdated(yesterdayShareRate, lastUpdateTime);
    }
}