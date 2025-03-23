const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TimeCapsule", function () {
  let TimeCapsule;
  let timeCapsule;
  let owner;
  let recipient;
  let addr1;
  let addr2;
  
  // Constants for tests
  const TITLE = "Test Capsule";
  const CONTENT_HASH = "QmXyZ123456789abcdef";
  const ONE_DAY = 24 * 60 * 60; // 1 day in seconds
  
  beforeEach(async function () {
    // Get the Contract Factory and signers
    TimeCapsule = await ethers.getContractFactory("TimeCapsule");
    [owner, recipient, addr1, addr2] = await ethers.getSigners();
    
    // Deploy the contract
    timeCapsule = await TimeCapsule.deploy();
    
    // Wait for deployment to complete
    await timeCapsule.deployed();
  });
  
  describe("Deployment", function () {
    it("Should have 0 capsules initially", async function () {
      expect(await timeCapsule.getCapsuleCount()).to.equal(0);
    });
  });
  
  describe("Time-based Capsule", function () {
    let capsuleId;
    let openTime;
    
    beforeEach(async function () {
      // Set open time to 1 day in the future
      const currentTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
      openTime = currentTimestamp + ONE_DAY;
      
      // Create a time-based capsule
      const tx = await timeCapsule.createTimeCapsule(
        TITLE,
        CONTENT_HASH,
        recipient.address,
        openTime
      );
      
      // Get the capsule ID from the event
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === 'CapsuleCreated');
      capsuleId = event.args.capsuleId;
    });
    
    it("Should create a time-based capsule correctly", async function () {
      const capsuleInfo = await timeCapsule.getCapsuleInfo(capsuleId);
      
      expect(capsuleInfo.title).to.equal(TITLE);
      expect(capsuleInfo.contentHash).to.equal(CONTENT_HASH);
      expect(capsuleInfo.creator).to.equal(owner.address);
      expect(capsuleInfo.recipient).to.equal(recipient.address);
      expect(capsuleInfo.openTime).to.equal(openTime);
      expect(capsuleInfo.status).to.equal(2); // CapsuleStatus.Sealed
      expect(capsuleInfo.conditionType).to.equal(0); // ConditionType.Time
    });
    
    it("Should not be ready to open before the open time", async function () {
      expect(await timeCapsule.isReadyToOpen(capsuleId)).to.be.false;
    });
    
    it("Should be ready to open after the open time", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [ONE_DAY + 1]);
      await ethers.provider.send("evm_mine");
      
      expect(await timeCapsule.isReadyToOpen(capsuleId)).to.be.true;
    });
    
    it("Should not allow non-recipient to open", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [ONE_DAY + 1]);
      await ethers.provider.send("evm_mine");
      
      await expect(
        timeCapsule.connect(addr1).openCapsule(capsuleId)
      ).to.be.revertedWith("Only recipient can open");
    });
    
    it("Should not open before the open time", async function () {
      await expect(
        timeCapsule.connect(recipient).openCapsule(capsuleId)
      ).to.be.revertedWith("Conditions not met to open capsule");
    });
    
    it("Should open after the open time", async function () {
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [ONE_DAY + 1]);
      await ethers.provider.send("evm_mine");
      
      // Open the capsule
      await timeCapsule.connect(recipient).openCapsule(capsuleId);
      
      // Check the status
      const capsuleInfo = await timeCapsule.getCapsuleInfo(capsuleId);
      expect(capsuleInfo.status).to.equal(4); // CapsuleStatus.Opened
    });
  });
  
  describe("Multi-signature Capsule", function () {
    let capsuleId;
    let signers;
    
    beforeEach(async function () {
      signers = [addr1.address, addr2.address];
      
      // Create a multi-signature capsule
      const tx = await timeCapsule.createMultiSigCapsule(
        TITLE,
        CONTENT_HASH,
        recipient.address,
        signers,
        signers.length // Require all signers
      );
      
      // Get the capsule ID from the event
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === 'CapsuleCreated');
      capsuleId = event.args.capsuleId;
    });
    
    it("Should create a multi-signature capsule correctly", async function () {
      const capsuleInfo = await timeCapsule.getCapsuleInfo(capsuleId);
      
      expect(capsuleInfo.title).to.equal(TITLE);
      expect(capsuleInfo.contentHash).to.equal(CONTENT_HASH);
      expect(capsuleInfo.creator).to.equal(owner.address);
      expect(capsuleInfo.recipient).to.equal(recipient.address);
      expect(capsuleInfo.status).to.equal(2); // CapsuleStatus.Sealed
      expect(capsuleInfo.conditionType).to.equal(1); // ConditionType.MultiSig
    });
    
    it("Should not be ready to open without approvals", async function () {
      expect(await timeCapsule.isReadyToOpen(capsuleId)).to.be.false;
    });
    
    it("Should not allow non-signers to approve", async function () {
      await expect(
        timeCapsule.connect(recipient).approveCapsuleOpening(capsuleId)
      ).to.be.revertedWith("Not authorized to approve");
    });
    
    it("Should be ready to open after all approvals", async function () {
      // Approve from signers
      await timeCapsule.connect(addr1).approveCapsuleOpening(capsuleId);
      await timeCapsule.connect(addr2).approveCapsuleOpening(capsuleId);
      
      expect(await timeCapsule.isReadyToOpen(capsuleId)).to.be.true;
    });
    
    it("Should open after all approvals", async function () {
      // Approve from signers
      await timeCapsule.connect(addr1).approveCapsuleOpening(capsuleId);
      await timeCapsule.connect(addr2).approveCapsuleOpening(capsuleId);
      
      // Open the capsule
      await timeCapsule.connect(recipient).openCapsule(capsuleId);
      
      // Check the status
      const capsuleInfo = await timeCapsule.getCapsuleInfo(capsuleId);
      expect(capsuleInfo.status).to.equal(4); // CapsuleStatus.Opened
    });
  });
});
