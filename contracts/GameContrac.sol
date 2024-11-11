pragma tvm-solidity >= 0.72.0;
pragma AbiHeader expire;

import {ITokens} from "TON-specific interface files"; // Replace with actual TON-compatible ERC20 interface

/// @title GameContract adapted for TON
contract GameContract {
    // Exception codes
    uint16 constant ERROR_NOT_OWNER = 100;
    uint16 constant ERROR_INSUFFICIENT_TOKENS = 101;

    ITokens public aeonToken;
    uint256 public nextTokenId;
    
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public playerScores;  // For leaderboard
    mapping(address => uint256) public stakedTokens;
    mapping(address => uint256) public stakingStartTime;
    uint256 public totalBurnedTokens;

    /// @dev Contract constructor.
    constructor(address _aeonToken) public {
        require(tvm.pubkey() != 0, 101);
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();

        aeonToken = ITokens(_aeonToken);
    }

    // Modifier that allows function to accept external call only if it was signed
    modifier checkOwnerAndAccept {
        require(msg.pubkey() == tvm.pubkey(), ERROR_NOT_OWNER);
        tvm.accept();
        _;
    }

    // --- Leaderboard Functions ---

    /// Updates player score
    function updatePlayerScore(address player, uint256 score) external checkOwnerAndAccept {
        playerScores[player] += score;
    }

    /// Get leaderboard
    function getLeaderboard(address[] memory players) public view returns (address[] memory, uint256[] memory) {
        uint256[] memory scores = new uint256[](players.length);
        for (uint256 i = 0; i < players.length; i++) {
            scores[i] = playerScores[players[i]];
        }
        return (players, scores);
    }

    // --- Staking System ---

    /// Stake AEON tokens
    function stakeTokens(uint256 amount) external {
        require(amount > 0, "Staking amount should be greater than 0");
        require(aeonToken.transferFrom(msg.sender, address(this), amount), "Stake transfer failed");

        stakedTokens[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
    }

    /// Claim staking rewards based on time staked
    function claimStakingRewards() external {
        uint256 stakedAmount = stakedTokens[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        uint256 stakingDuration = block.timestamp - stakingStartTime[msg.sender];
        uint256 rewardAmount = calculateStakingReward(stakedAmount, stakingDuration);

        require(aeonToken.transfer(msg.sender, rewardAmount), "Reward transfer failed");
        stakingStartTime[msg.sender] = block.timestamp;
    }

    // Helper function to calculate staking reward
    function calculateStakingReward(uint256 amount, uint256 duration) internal pure returns (uint256) {
        uint256 rewardRate = 5;
        return (amount * rewardRate * duration) / (100 * 365 days);
    }

    /// Unstake tokens
    function unstakeTokens() external {
        uint256 stakedAmount = stakedTokens[msg.sender];
        require(stakedAmount > 0, "No tokens staked");

        stakedTokens[msg.sender] = 0;
        stakingStartTime[msg.sender] = 0;
        require(aeonToken.transfer(msg.sender, stakedAmount), "Unstake transfer failed");
    }

    // --- Token Burning Mechanism ---

    /// Burn AEON tokens from contract balance
    function burnTokens(uint256 amount) external checkOwnerAndAccept {
        require(aeonToken.balanceOf(address(this)) >= amount, "Insufficient tokens to burn");
        require(aeonToken.transfer(address(0), amount), "Burn transfer failed");
        totalBurnedTokens += amount;
    }
}
