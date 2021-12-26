// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// gego
import "./library/Governance.sol";
import "./interface/IPool.sol";
import "./interface/ISpyNFTFactory.sol";
import "./interface/ISpyNFT.sol";


contract GeneralNFTReward is IPool,Governance {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public _rewardERC20 = IERC20(address(0x0));
    ISpyNFTFactory public _gegoFactory = ISpyNFTFactory(address(0x0));
    ISpyNFT public _gegoToken = ISpyNFT(address(0x0));
    address public _playerBook = address(0x0);

    address public _teamWallet = address(0x0);
    address public _rewardPool = address(0x0);

    uint256 public constant DURATION = 7 days;
    uint256 public _startTime =  1629028800;
    uint256 public _periodFinish = 0;
    uint256 public _rewardRate = 0;
    uint256 public _lastUpdateTime;
    uint256 public _rewardPerTokenStored;
    uint256 public _harvestInterval = 12 hours;
    uint256 public totalLockedUpRewards;

    uint256 public _teamRewardRate = 1000;
    uint256 public _poolRewardRate = 1000;
    uint256 public _baseRate = 10000;
    uint256 public _punishTime = 3 days;
    // The precision factor
    uint256 public REWARDS_PRECISION_FACTOR;

    mapping(address => uint256) public _userRewardPerTokenPaid;
    mapping(address => uint256) public _rewards;
    mapping(address => uint256) public _lastStakedTime;
    mapping(address => uint256) public _nextHarvestUntil;
    mapping(address => uint256) public _rewardLockedUp;

    uint256 public _fixRateBase = 100000;

    uint256 public _totalWeight;
    mapping(address => uint256) public _weightBalances;
    mapping(uint256 => uint256) public _stakeWeightes;
    mapping(uint256 => uint256) public _stakeBalances;

    uint256 public _totalBalance;
    mapping(address => uint256) public _degoBalances;
    // uint256 public _maxStakedDego = 200 * 1e18;
    uint256 public _maxStakedDego = 200;

    mapping(address => uint256[]) public _playerGego;
    mapping(uint256 => uint256) public _gegoMapIndex;



    event RewardAdded(uint256 reward);
    event StakedGEGO(address indexed user, uint256 amount);
    event WithdrawnGego(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardLockedUp(address indexed user, uint256 reward);
    event NFTReceived(address operator, address from, uint256 tokenId, bytes data);

    constructor(address spyNftToken, address gegoFactory, address rewardAddress, uint256 startTime) {
        _rewardERC20 = IERC20(rewardAddress);
        _gegoToken = ISpyNFT(spyNftToken);
        _gegoFactory = ISpyNFTFactory(gegoFactory);

        uint256 decimalsRewardToken = uint256(ERC20(rewardAddress).decimals());
        require(decimalsRewardToken < 18, "Must be inferior to 18");

        REWARDS_PRECISION_FACTOR = uint256(10**(uint256(18).sub(decimalsRewardToken)));

        _startTime = startTime;
        _lastUpdateTime = _startTime;
    }


    modifier updateReward(address account) {
        _rewardPerTokenStored = rewardPerToken();
        _lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
        _;
    }

    function setMaxStakedDego(uint256 amount) external onlyGovernance{
        _maxStakedDego = amount;
    }

    /* Fee collection for any other token */
    function seize(IERC20 token, uint256 amount) external  {
        require(token != _rewardERC20, "reward");
        token.transfer(_governance, amount);
    }

    /* Fee collection for any other token */
    function seizeErc721(IERC721 token, uint256 tokenId) external
    {
        require(token != _gegoToken, "gego stake");
        token.safeTransferFrom(address(this), _governance, tokenId);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, _periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return _rewardPerTokenStored;
        }
        return
            _rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(_lastUpdateTime)
                    .mul(_rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return earnedInternal(account).div(REWARDS_PRECISION_FACTOR);
    }

    function earnedInternal(address account) private view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(_userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(_rewards[account]);
    }

    function canHarvest(address account) public view returns (bool) {
        return block.timestamp >= _nextHarvestUntil[account];
    }

    //the grade is a number between 1-6
    //the quality is a number between 1-10000
    /*
    1   quality	1.1+ 0.1*quality/5000
    2	quality	1.2+ 0.1*(quality-5000)/3000
    3	quality	1.3+ 0.1*(quality-8000/1000
    4	quality	1.4+ 0.2*(quality-9000)/800
    5	quality	1.6+ 0.2*(quality-9800)/180
    6	quality	1.8+ 0.2*(quality-9980)/20
    */

    function getFixRate(uint256 grade,uint256 quality) public pure returns (uint256){

        require(grade > 0 && grade < 7, "the gego not dego");

        uint256 unfold = 0;

        if( grade == 1 ){
            unfold = quality*10000/5000;
            return unfold.add(110000);
        }else if( grade == 2){
            unfold = quality.sub(5000)*10000/3000;
            return unfold.add(120000);
        }else if( grade == 3){
            unfold = quality.sub(8000)*10000/1000;
           return unfold.add(130000);
        }else if( grade == 4){
            unfold = quality.sub(9000)*20000/800;
           return unfold.add(140000);
        }else if( grade == 5){
            unfold = quality.sub(9800)*20000/180;
            return unfold.add(160000);
        }else{
            unfold = quality.sub(9980)*20000/20;
            return unfold.add(180000);
        }
    }

    function getStakeInfo( uint256 gegoId ) public view returns ( uint256 stakeRate, uint256 degoAmount){

        uint256 grade;
        uint256 quality;
        uint256 createdTime;
        uint256 blockNum;
        uint256 resId;
        address author;

        (grade, quality, degoAmount,resId, , , ,author, ,createdTime,blockNum,) = _gegoFactory.getGego(gegoId);

        require(degoAmount > 0,"the gego not dego");

        stakeRate = getFixRate(grade,quality);
    }

    // stake NFT
    function stake(uint256 gegoId)
        public
        updateReward(msg.sender)
        checkStart
    {

        uint256[] storage gegoIds = _playerGego[msg.sender];
        if (gegoIds.length == 0) {
            gegoIds.push(0);
            _gegoMapIndex[0] = 0;
        }
        gegoIds.push(gegoId);
        _gegoMapIndex[gegoId] = gegoIds.length - 1;

        uint256 stakeRate;
        uint256 degoAmount;
        (stakeRate, degoAmount) = getStakeInfo(gegoId);

        uint256 stakedDegoAmount = _degoBalances[msg.sender];
        uint256 stakingDegoAmount = stakedDegoAmount.add(degoAmount) <= _maxStakedDego?degoAmount:_maxStakedDego.sub(stakedDegoAmount);


        if(stakingDegoAmount > 0){
            uint256 stakeWeight = stakeRate.mul(stakingDegoAmount).div(_fixRateBase);
            _degoBalances[msg.sender] = _degoBalances[msg.sender].add(stakingDegoAmount);

            _weightBalances[msg.sender] = _weightBalances[msg.sender].add(stakeWeight);

            _stakeBalances[gegoId] = stakingDegoAmount;
            _stakeWeightes[gegoId] = stakeWeight;

            _totalBalance = _totalBalance.add(stakingDegoAmount);
            _totalWeight = _totalWeight.add(stakeWeight);
        }

        _gegoToken.safeTransferFrom(msg.sender, address(this), gegoId);

        if(_nextHarvestUntil[msg.sender] == 0){
            _nextHarvestUntil[msg.sender] = block.timestamp.add(
                    _harvestInterval
                );
        }
        _lastStakedTime[msg.sender] = block.timestamp;
        emit StakedGEGO(msg.sender, gegoId);

    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        emit NFTReceived(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function unstake(uint256 gegoId)
        public
        updateReward(msg.sender)
        checkStart
    {
        require(gegoId > 0, "the gegoId error");

        uint256[] memory gegoIds = _playerGego[msg.sender];
        uint256 gegoIndex = _gegoMapIndex[gegoId];

        require(gegoIds[gegoIndex] == gegoId, "not gegoId owner");

        uint256 gegoArrayLength = gegoIds.length-1;
        uint256 tailId = gegoIds[gegoArrayLength];

        _playerGego[msg.sender][gegoIndex] = tailId;
        _playerGego[msg.sender][gegoArrayLength] = 0;

        // _playerGego[msg.sender].length--;  // remove in new version

        _playerGego[msg.sender].pop();

        _gegoMapIndex[tailId] = gegoIndex;
        _gegoMapIndex[gegoId] = 0;

        uint256 stakeWeight = _stakeWeightes[gegoId];
        _weightBalances[msg.sender] = _weightBalances[msg.sender].sub(stakeWeight);
        _totalWeight = _totalWeight.sub(stakeWeight);

        uint256 stakeBalance = _stakeBalances[gegoId];
        _degoBalances[msg.sender] = _degoBalances[msg.sender].sub(stakeBalance);
        _totalBalance = _totalBalance.sub(stakeBalance);

        _gegoToken.safeTransferFrom(address(this), msg.sender, gegoId);

        _stakeBalances[gegoId] = 0;
        _stakeWeightes[gegoId] = 0;

        emit WithdrawnGego(msg.sender, gegoId);
    }

    function withdraw()
        public
        checkStart
    {

        uint256[] memory gegoId = _playerGego[msg.sender];
        for (uint8 index = 1; index < gegoId.length; index++) {
            if (gegoId[index] > 0) {
                unstake(gegoId[index]);
            }
        }
    }

    function getPlayerIds( address account ) public view returns( uint256[] memory gegoId )
    {
        gegoId = _playerGego[account];
    }

    function exit() external {
        withdraw();
        harvest();
    }

    function harvest() public updateReward(msg.sender) checkStart {
        uint256 reward = earnedInternal(msg.sender);
        if(canHarvest(msg.sender)){
            if (reward > 0 || _rewardLockedUp[msg.sender] > 0) {
                _rewards[msg.sender] = 0;
                reward = reward.add(_rewardLockedUp[msg.sender]);
                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(_rewardLockedUp[msg.sender]);
                _rewardLockedUp[msg.sender] = 0;
                _nextHarvestUntil[msg.sender] = block.timestamp.add(
                    _harvestInterval
                );

                // reward for team
                uint256 teamReward = reward.mul(_teamRewardRate).div(_baseRate);
                uint256 teamRewardWithDecimal = teamReward.div(REWARDS_PRECISION_FACTOR);
                if(teamRewardWithDecimal>0 && _teamWallet != address(0)){
                    _rewardERC20.safeTransfer(_teamWallet, teamRewardWithDecimal);
                }
                uint256 leftReward = reward.sub(teamReward);
                uint256 poolReward = 0;

                //withdraw time check

                if(block.timestamp < (_lastStakedTime[msg.sender] + _punishTime)){
                    poolReward = leftReward.mul(_poolRewardRate).div(_baseRate);
                }
                if(poolReward>0){
                    uint256 poolRewardWithDecimal = poolReward.div(REWARDS_PRECISION_FACTOR);
                    if (poolRewardWithDecimal > 0 && _rewardPool != address(0)) {
                        _rewardERC20.safeTransfer(_rewardPool, poolReward);
                    }
                    leftReward = leftReward.sub(poolReward);
                }

                uint256 leftRewardWithDecimal = leftReward.div(REWARDS_PRECISION_FACTOR);
                if(leftRewardWithDecimal>0){
                    _rewardERC20.safeTransfer(msg.sender, leftRewardWithDecimal);
                }
                emit RewardPaid(msg.sender, leftRewardWithDecimal);
            }
        } else if(reward > 0){
            _rewards[msg.sender] = 0;
            _rewardLockedUp[msg.sender] = _rewardLockedUp[msg.sender].add(reward);
            totalLockedUpRewards = totalLockedUpRewards.add(reward);

            uint256 rewardWithDecimal = reward.div(REWARDS_PRECISION_FACTOR);
            emit RewardLockedUp(msg.sender, rewardWithDecimal);
        }
    }

    modifier checkStart() {
        require(block.timestamp > _startTime, "not start");
        _;
    }

    //for extra reward
    function notifyReward(uint256 reward)
        external
        onlyGovernance
        updateReward(address(0))
    {

        uint256 balanceBefore = _rewardERC20.balanceOf(address(this));
        IERC20(_rewardERC20).transferFrom(msg.sender, address(this), reward);
        uint256 balanceEnd = _rewardERC20.balanceOf(address(this));

        uint256 realReward = balanceEnd.sub(balanceBefore).mul(REWARDS_PRECISION_FACTOR);

        if (block.timestamp >= _periodFinish) {
            _rewardRate = realReward.div(DURATION);
        } else {
            uint256 remaining = _periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(_rewardRate);
            _rewardRate = realReward.add(leftover).div(DURATION);
        }
        _lastUpdateTime = block.timestamp;
        _periodFinish = block.timestamp.add(DURATION);

        emit RewardAdded(realReward);
    }

    function setTeamRewardRate( uint256 teamRewardRate ) public onlyGovernance {
        _teamRewardRate = teamRewardRate;
    }

    function setPoolRewardRate( uint256  poolRewardRate ) public onlyGovernance{
        _poolRewardRate = poolRewardRate;
    }
    
    function setHarvestInterval( uint256  harvestInterval ) public onlyGovernance{
        _harvestInterval = harvestInterval;
    }

    function setRewardPool( address  rewardPool ) public onlyGovernance{
        _rewardPool = rewardPool;
    }

    function setTeamWallet( address teamwallet ) public onlyGovernance{
        _teamWallet = teamwallet;
    }

    function totalSupply()  public view override returns (uint256) {
        return _totalWeight;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _weightBalances[account];
    }

    function setWithDrawPunishTime( uint256  punishTime ) public onlyGovernance{
        _punishTime = punishTime;
    }

}