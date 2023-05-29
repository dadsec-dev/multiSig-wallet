// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
import "openzeppelin-contracts//utils/Counters.sol";

contract MultiSigWallet {
    using Counters for Counters.Counter;
    Counters.Counter public totaltr;

    // @dev events
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    address[] public owners;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool isExecuted;
    }
    Transaction[] public transactions;

    // uint256 public id;
    mapping(uint256 => Transaction) public tr;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public approved;
    

    

    // @notice --- modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "unauthorized entity");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "invalid tx");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].isExecuted, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "owners cannot be empty");
        require(_required > 0 && _required <= _owners.length, "invalid input");

        for (uint256 i; i < _owners.length; i++) {
            address owner = owners[i];
            require(owner != address(0), "invalid address");
            require(!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        totaltr.increment();
        uint256 id = totaltr.current();
        Transaction storage transaction = tr[id];

        transaction.to = _to;
        transaction.value = _value;
        transaction.data = _data;
        transaction.isExecuted = false;

        transactions.push(transaction);

        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function getApprovalCount(uint256 _txId) private view returns(uint256 count){
        for (uint i; i<owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint256 _txId) public txExists(_txId) notExecuted(_txId) {
        require(getApprovalCount(_txId) >= required, 'approvals incomplete');
        Transaction storage transaction = transactions[_txId];

        transaction.isExecuted = true;

       (bool sent, ) = transaction.to.call{value: transaction.value}(transaction.data);
       require(sent, 'tx failed');

       emit Execute(_txId);
    }

    function revoke(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "u didn't approve");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
