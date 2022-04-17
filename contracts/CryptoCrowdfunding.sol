// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CryptoCrowdfunding is Ownable {
    event Launch(
        uint256 indexed id,
        address indexed creator,
        uint256 goal,
        uint32 startAt,
        uint32 endAt
    );
    event Cancel(uint256 indexed id);
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Unpledge(uint256 indexed id, address indexed caller, uint256 amount);
    event Claim(uint256 indexed id);
    event Refund(uint256 indexed id, address indexed caller, uint256 amount);
    event TransferCampaign(
        uint256 indexed id,
        address indexed caller,
        address indexed newCreator
    );

    struct Campaign {
        // Creator of campaign
        address creator;
        // Amount of tokens to raise
        uint256 goal;
        // Total amount pledged
        uint256 pledged;
        // Timestamp of start of campaign
        uint32 startAt;
        // Timestamp of end of campaign
        uint32 endAt;
        // True if campaign uses a custom token
        bool isCustomTokenEnabled;
        // Set to dead/zero address if not custom token
        address customTokenAddress;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }

    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint256 public count;
    // Mapping from id to Campaign
    mapping(uint256 => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;
    // Campaign max duration
    uint256 public campaignMaxDuration = 365 days;
    // Campaign claim fee & max fee
    uint256 public fee = 100; // 1.00 %
    uint256 public maxFee = 700; // 7.00 %

    constructor() {}

    modifier onlyCreator(uint256 _id) {
        Campaign memory campaign = campaigns[_id];
        require(campaign.creator == msg.sender, "not creator");
        _;
    }

    function launch(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt,
        bool _isCustomTokenEnabled,
        address _customTokenAddress
    ) external {
        require(_startAt >= block.timestamp, "start at < now");
        require(_endAt >= _startAt, "end at < start at");
        require(
            _endAt <= block.timestamp + campaignMaxDuration,
            "end at > max duration"
        );
        require(
            !_isCustomTokenEnabled || msg.sender == owner(),
            "Only the Admin can create a custom token campaign"
        );

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            isCustomTokenEnabled: _isCustomTokenEnabled,
            customTokenAddress: _customTokenAddress,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function transferCampaign(uint256 _id, address _newCreator) external onlyCreator(_id) {
        Campaign memory campaign = campaigns[_id];
        campaign.creator = _newCreator;

        emit TransferCampaign(_id, msg.sender, _newCreator);
    }

    function cancel(uint256 _id) external onlyCreator(_id) {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp < campaign.startAt, "started");

        delete campaigns[_id];

        emit Cancel(_id);
    }

    function pledge(uint256 _id, uint256 _amount) external payable {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not started");
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;

        if (campaign.isCustomTokenEnabled) {
            IERC20(campaign.customTokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        } else {
            require(msg.value >= _amount, "sent amount mismatch");
        }

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");

        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;

        if (campaign.isCustomTokenEnabled) {
            IERC20(campaign.customTokenAddress).transfer(msg.sender, _amount);
        } else {
            Address.sendValue(payable(msg.sender), _amount);
        }

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external onlyCreator(_id) {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;

        uint256 campaignFee = (campaign.pledged * fee) / 10000;
        uint256 creatorAmount = campaign.pledged - campaignFee;

        if (campaign.isCustomTokenEnabled) {
            IERC20(campaign.customTokenAddress).transfer(owner(), campaignFee);
            IERC20(campaign.customTokenAddress).transfer(
                campaign.creator,
                creatorAmount
            );
        } else {
            Address.sendValue(payable(owner()), campaignFee);
            Address.sendValue(payable(campaign.creator), creatorAmount);
        }

        emit Claim(_id);
    }

    function refund(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledged < campaign.goal, "pledged >= goal");

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;

        if (campaign.isCustomTokenEnabled) {
            IERC20(campaign.customTokenAddress).transfer(msg.sender, bal);
        } else {
            Address.sendValue(payable(msg.sender), bal);
        }

        emit Refund(_id, msg.sender, bal);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= maxFee, "Fee over the limit");

        fee = _fee;
    }
}
