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
    event Pledge(uint256 indexed id, address indexed caller, uint256 amount);
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
        // Total amount refunded
        uint256 refunded;
        // Timestamp of start of campaign
        uint32 startAt;
        // Timestamp of end of campaign
        uint32 endAt;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }

    // Total count of campaigns created.
    // It is also used to generate id for new campaigns.
    uint256 public count;
    // Total money raised
    uint256 public moneyCount;
    // Total number of contributions
    uint256 public contributionCount;
    // Mapping from id to Campaign
    mapping(uint256 => Campaign) public campaigns;
    // Mapping from campaign id => pledger => amount pledged
    mapping(uint256 => mapping(address => uint256)) public pledgedAmount;
    // Campaign max duration
    uint256 public campaignMaxDuration = 365 days;
    // Campaign claim fee & max fee
    uint256 public claimFee = 500; // 5.00 %
    uint256 public maxFee = 1000; // 10.00 %
    // Campaign claim limit
    uint256 public claimLimit = 1 days;

    // Campaign launch fee
    uint256 public launchFee = 0.001 ether;

    constructor() {}

    modifier onlyCreator(uint256 _id) {
        Campaign memory campaign = campaigns[_id];
        require(
            campaign.creator == msg.sender,
            "Can't perform this action, sender is not the owner of the Campaign."
        );
        _;
    }

    function launch(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external payable {
        if (_startAt < block.timestamp) _startAt = uint32(block.timestamp);

        require(
            _endAt >= _startAt,
            "Error: end date needs to be grater than start date."
        );
        require(
            _endAt - _startAt <= campaignMaxDuration,
            "Error: campaign can't last more than 1 year"
        );

        if (msg.sender != owner()) {
            require(
                msg.value >= launchFee,
                "Error: Lauch fee not payed. Send more ETH"
            );
        }

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        Address.sendValue(payable(owner()), msg.value);

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function transferCampaign(uint256 _id, address _newCreator)
        external
        onlyCreator(_id)
    {
        Campaign memory campaign = campaigns[_id];
        campaign.creator = _newCreator;

        emit TransferCampaign(_id, msg.sender, _newCreator);
    }

    function pledge(uint256 _id) external payable {
        uint256 _amount = msg.value;
        Campaign storage campaign = campaigns[_id];
        require(
            block.timestamp >= campaign.startAt,
            "Error: campaign is not started yet."
        );
        require(
            block.timestamp <= campaign.endAt,
            "Error: campaign is already ended."
        );

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;

        contributionCount += 1;

        emit Pledge(_id, msg.sender, _amount);
    }

    function claim(uint256 _id) external onlyCreator(_id) {
        Campaign storage campaign = campaigns[_id];
        require(
            block.timestamp > campaign.endAt,
            "Error: campaign is not ended yet."
        );
        require(
            campaign.pledged >= campaign.goal,
            "Error: pledged amout didn't reach the campaign goal."
        );
        require(!campaign.claimed, "Error: already claimed.");

        campaign.claimed = true;

        uint256 campaignFee = (campaign.pledged * claimFee) / 10000;
        uint256 creatorAmount = campaign.pledged - campaignFee;

        Address.sendValue(payable(owner()), campaignFee);
        Address.sendValue(payable(campaign.creator), creatorAmount);

        moneyCount += campaign.pledged;

        emit Claim(_id);
    }

    function adminClaim(uint256 _id) external onlyOwner {
        Campaign storage campaign = campaigns[_id];
        require(
            block.timestamp > campaign.endAt + claimLimit,
            "Error: claim limit is not reached yet."
        );
        require(!campaign.claimed, "Error: already claimed.");

        campaign.claimed = true;

        Address.sendValue(
            payable(owner()),
            campaign.pledged - campaign.refunded
        );
    }

    function refund(uint256 _id) external {
        Campaign memory campaign = campaigns[_id];
        require(
            block.timestamp > campaign.endAt,
            "Error: campaing didn't end yet."
        );
        require(
            campaign.pledged < campaign.goal,
            "Error: plaedged amount exceeds the campaign goal."
        );

        uint256 bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender] = 0;
        campaign.refunded += bal;

        Address.sendValue(payable(msg.sender), bal);

        emit Refund(_id, msg.sender, bal);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= maxFee, "Error: fee can't go over the fee limit.");

        claimFee = _fee;
    }
}
