// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameContract is ERC721, Ownable, ReentrancyGuard {
    IERC20 public aeonToken;
    uint256 public nextTokenId;
    
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public playerScores;  // For leaderboard
    mapping(address => uint256) public stakedTokens;
    mapping(address => uint256) public stakingStartTime;
    
    uint256 public totalBurnedTokens;

    constructor(address _aeonToken) ERC721("GameNFT", "GNFT") {
        aeonToken = IERC20(_aeonToken);
    }

    // --- Leaderboard Functions ---

    // Updates player score; can be called based on achievements
    function updatePlayerScore(address player, uint256 score) external onlyOwner {
        playerScores[player] += score;
    }

    // Get top players by score (Leaderboard)
    function getLeaderboard(address[] memory players) public view returns (address[] memory, uint256[] memory) {
        uint256[] memory scores = new uint256[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            scores[i] = playerScores[players[i]];
        }
        return (players, scores);
    }

    // --- Staking System ---

    // Stake AEON tokens
    function stakeTokens(uint256 amount) external nonReentrant {
        require(amount > 0, "Staking amount should be greater than 0");
        require(aeonToken.transferFrom(msg.sender, address(this), amount), "Stake transfer failed");

        // Update player's staking data
        stakedTokens[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
    }

    // Claim staking rewards based on time staked
    function claimStakingRewards() external nonReentrant {
        uint256 stakedAmount = stakedTokens[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        // Calculate staking duration and rewards
        uint256 stakingDuration = block.timestamp - stakingStartTime[msg.sender];
        uint256 rewardAmount = calculateStakingReward(stakedAmount, stakingDuration);

        // Transfer reward tokens and reset staking time
        require(aeonToken.transfer(msg.sender, rewardAmount), "Reward transfer failed");
        stakingStartTime[msg.sender] = block.timestamp;
    }

    // Helper function to calculate staking reward based on duration
    function calculateStakingReward(uint256 amount, uint256 duration) internal pure returns (uint256) {
        uint256 rewardRate = 5; // 5% reward rate as an example
        return (amount * rewardRate * duration) / (100 * 365 days); // Annual reward rate
    }

    // Unstake tokens
    function unstakeTokens() external nonReentrant {
        uint256 stakedAmount = stakedTokens[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        // Reset staking data and transfer staked tokens back to the user
        stakedTokens[msg.sender] = 0;
        stakingStartTime[msg.sender] = 0;
        require(aeonToken.transfer(msg.sender, stakedAmount), "Unstake transfer failed");
    }

    // --- Token Burning Mechanism ---

    // Burn AEON tokens from the contract's balance
    function burnTokens(uint256 amount) external onlyOwner {
        require(aeonToken.balanceOf(address(this)) >= amount, "Insufficient tokens to burn");
        require(aeonToken.transfer(address(0), amount), "Burn transfer failed");
        totalBurnedTokens += amount;
    }
}
