import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function deployFixture() {
  const [owner, signer2, payer, other] = await ethers.getSigners();
  const Factory = await ethers.getContractFactory("MisarMailPaymentOracle");
  const oracle = await Factory.deploy(owner.address);
  return { oracle, owner, signer2, payer, other };
}

function makePaymentId(n: number): string {
  return ethers.zeroPadValue(ethers.toBeHex(n), 32);
}

async function signPayment(
  signer: Awaited<ReturnType<typeof ethers.getSigner>>,
  paymentId: string,
  payer: string,
  amount: bigint,
  emailCount: bigint
): Promise<string> {
  const hash = ethers.solidityPackedKeccak256(
    ["bytes32", "address", "uint256", "uint256"],
    [paymentId, payer, amount, emailCount]
  );
  return signer.signMessage(ethers.getBytes(hash));
}

describe("MisarMailPaymentOracle", () => {
  it("deploys and sets trusted signer", async () => {
    const { oracle, owner } = await loadFixture(deployFixture);
    expect(await oracle.trustedSigner()).to.equal(owner.address);
  });

  it("recordPayment with valid sig emits PaymentRecorded", async () => {
    const { oracle, owner, payer } = await loadFixture(deployFixture);
    const paymentId = makePaymentId(1);
    const amount = ethers.parseEther("0.01");
    const emailCount = 100n;

    const sig = await signPayment(owner, paymentId, payer.address, amount, emailCount);

    await expect(oracle.recordPayment(paymentId, payer.address, amount, emailCount, sig))
      .to.emit(oracle, "PaymentRecorded")
      .withArgs(paymentId, payer.address, amount, emailCount);

    expect(await oracle.verifyPayment(paymentId)).to.be.true;
  });

  it("reverts InvalidSignature on wrong signer", async () => {
    const { oracle, signer2, payer } = await loadFixture(deployFixture);
    const paymentId = makePaymentId(2);
    const amount = ethers.parseEther("0.01");
    const emailCount = 50n;

    const sig = await signPayment(signer2, paymentId, payer.address, amount, emailCount);

    await expect(
      oracle.recordPayment(paymentId, payer.address, amount, emailCount, sig)
    ).to.be.revertedWithCustomError(oracle, "InvalidSignature");
  });

  it("reverts PaymentAlreadyRecorded on replay", async () => {
    const { oracle, owner, payer } = await loadFixture(deployFixture);
    const paymentId = makePaymentId(3);
    const amount = ethers.parseEther("0.01");
    const emailCount = 10n;

    const sig = await signPayment(owner, paymentId, payer.address, amount, emailCount);
    await oracle.recordPayment(paymentId, payer.address, amount, emailCount, sig);

    await expect(
      oracle.recordPayment(paymentId, payer.address, amount, emailCount, sig)
    ).to.be.revertedWithCustomError(oracle, "PaymentAlreadyRecorded");
  });

  it("getCumulativeEmailCount tracks totals across payments", async () => {
    const { oracle, owner, payer } = await loadFixture(deployFixture);
    const amount = ethers.parseEther("0.01");

    const id1 = makePaymentId(4);
    const count1 = 100n;
    const sig1 = await signPayment(owner, id1, payer.address, amount, count1);
    await oracle.recordPayment(id1, payer.address, amount, count1, sig1);

    const id2 = makePaymentId(5);
    const count2 = 200n;
    const sig2 = await signPayment(owner, id2, payer.address, amount, count2);
    await oracle.recordPayment(id2, payer.address, amount, count2, sig2);

    expect(await oracle.getCumulativeEmailCount(payer.address)).to.equal(count1 + count2);
  });

  it("onlyOwner can updateTrustedSigner", async () => {
    const { oracle, owner, signer2, other } = await loadFixture(deployFixture);

    await expect(
      oracle.connect(other).updateTrustedSigner(other.address)
    ).to.be.revertedWithCustomError(oracle, "OwnableUnauthorizedAccount");

    await oracle.connect(owner).updateTrustedSigner(signer2.address);
    expect(await oracle.trustedSigner()).to.equal(signer2.address);
  });
});
