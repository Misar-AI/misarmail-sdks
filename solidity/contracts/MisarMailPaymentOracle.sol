// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MisarMailPaymentOracle is Ownable {
    using ECDSA for bytes32;

    address public trustedSigner;

    struct PaymentRecord {
        bool recorded;
        uint256 amount;
        uint256 emailCount;
        uint256 timestamp;
    }

    mapping(bytes32 => PaymentRecord) public payments;
    mapping(address => uint256) public cumulativeEmailCount;

    event PaymentRecorded(
        bytes32 indexed paymentId,
        address indexed payer,
        uint256 amount,
        uint256 emailCount
    );

    error InvalidSignature();
    error PaymentAlreadyRecorded();
    error ZeroAmount();

    constructor(address _trustedSigner) Ownable(msg.sender) {
        trustedSigner = _trustedSigner;
    }

    function recordPayment(
        bytes32 paymentId,
        address payer,
        uint256 amount,
        uint256 emailCount,
        bytes calldata signature
    ) external {
        if (amount == 0) revert ZeroAmount();
        if (payments[paymentId].recorded) revert PaymentAlreadyRecorded();

        bytes32 hash = keccak256(abi.encodePacked(paymentId, payer, amount, emailCount));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(hash);
        address recovered = ethHash.recover(signature);
        if (recovered != trustedSigner) revert InvalidSignature();

        payments[paymentId] = PaymentRecord({
            recorded: true,
            amount: amount,
            emailCount: emailCount,
            timestamp: block.timestamp
        });
        cumulativeEmailCount[payer] += emailCount;

        emit PaymentRecorded(paymentId, payer, amount, emailCount);
    }

    function verifyPayment(bytes32 paymentId) external view returns (bool) {
        return payments[paymentId].recorded;
    }

    function getCumulativeEmailCount(address payer) external view returns (uint256) {
        return cumulativeEmailCount[payer];
    }

    function updateTrustedSigner(address newSigner) external onlyOwner {
        trustedSigner = newSigner;
    }
}
