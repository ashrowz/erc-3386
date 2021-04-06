const { ethers } = require("hardhat")
const { BigNumber } = ethers;
const { use, expect } = require("chai")
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("WrappedERC721", function () {
  before(async function () {
    this.AERC721 = await ethers.getContractFactory("AERC721")
    this.WrappedERC721 = await ethers.getContractFactory("WrappedERC721")
    this.signers = await ethers.getSigners()
    this.alpha = this.signers[0]
    this.beta = this.signers[1]
    this.omega = this.signers[2]
  })

  beforeEach(async function () {
    this.base = await this.AERC721.deploy("A", "A")
    this.wrapped = await this.WrappedERC721.deploy("WrappedA", "WA", 32, this.base.address, 2)
    await this.wrapped.deployed()

    await this.base.safeMint(this.alpha.address, "0x00", "0x00")
    await this.base.connect(this.alpha).approve(this.wrapped.address, "0x00")

    for (const id of [...Array(9).keys()].map(i => BigNumber.from(i + 1))) {
      await this.base.safeMint(this.beta.address, id, "0x00")
      await this.base.connect(this.beta).approve(this.wrapped.address, id)
    }
  })

  it("should have correct name and symbol and decimal", async function () {
    expect(await this.wrapped.name()).to.equal("WrappedA")
    expect(await this.wrapped.symbol()).to.equal("WA")
    expect(await this.wrapped.decimals()).to.equal(18)
  })

  it("should only allow approved to mint and burn tokens", async function () {
    await expect(this.wrapped.connect(this.alpha).batchMint(this.omega.address, ["0x00", "0x01"], [1, 1]))
      .to.be.revertedWith("ERC721: transfer of token that is not own")

    await this.wrapped.connect(this.alpha).mint(this.omega.address, "0x00", 1)
    await this.wrapped.connect(this.beta).batchMint(this.omega.address, ["0x01", "0x02", "0x03", "0x04", "0x05"], [1, 1, 1, 1, 1])

    expect(await this.wrapped.totalSupply()).to.equal(12)
    expect(await this.wrapped.balanceOf(this.alpha.address)).to.equal(0)
    expect(await this.wrapped.balanceOf(this.beta.address)).to.equal(0)
    expect(await this.wrapped.balanceOf(this.omega.address)).to.equal(12)

    for (id of ["0x00", "0x01", "0x02", "0x03", "0x04", "0x05"]) {
      expect(await this.base.ownerOf(id)).to.equal(this.wrapped.address)
    }

    await expect(this.wrapped.connect(this.omega).mint(this.omega.address, "0x00", 1))
      .to.be.revertedWith("ERC721: transfer of token that is not own")

    await expect(this.wrapped.connect(this.omega).batchMint(this.omega.address, ["0x00"], [1]))
      .to.be.revertedWith("ERC721: transfer of token that is not own")

    await expect(this.wrapped.connect(this.alpha).burn(this.alpha.address, this.omega.address, 1))
      .to.be.revertedWith("ERC20: burn amount exceeds allowance")

    await expect(this.wrapped.connect(this.alpha).idBurn(this.alpha.address, this.omega.address, "0x00", 1))
      .to.be.revertedWith("ERC20: burn amount exceeds allowance")

    await expect(this.wrapped.connect(this.alpha).batchBurn(this.alpha.address, this.omega.address, [1]))
      .to.be.revertedWith("ERC20: burn amount exceeds allowance")

    await expect(this.wrapped.connect(this.alpha).batchIdBurn(this.alpha.address, this.omega.address, ["0x00"], [1]))
      .to.be.revertedWith("ERC20: burn amount exceeds allowance")

    await this.wrapped.connect(this.omega).approve(this.omega.address, 12)

    await this.wrapped.connect(this.omega).idBurn(this.omega.address, this.alpha.address, "0x02", 1)
    expect(await this.base.ownerOf("0x02")).to.equal(this.alpha.address)

    await this.wrapped.connect(this.omega).batchIdBurn(this.omega.address, this.beta.address, ["0x01", "0x05"], [1, 1])
    expect(await this.base.ownerOf("0x01")).to.equal(this.beta.address)
    expect(await this.base.ownerOf("0x05")).to.equal(this.beta.address)

    await this.wrapped.connect(this.omega).burn(this.omega.address, this.alpha.address, 1)
    expect(await this.base.ownerOf("0x04")).to.equal(this.alpha.address)

    await this.wrapped.connect(this.omega).batchBurn(this.omega.address, this.beta.address, [1, 1])
    expect(await this.base.ownerOf("0x03")).to.equal(this.beta.address)
    expect(await this.base.ownerOf("0x00")).to.equal(this.beta.address)

    await expect(this.wrapped.connect(this.omega).idBurn(this.omega.address, this.beta.address, "0x05", 1))
      .to.be.revertedWith("WrappedERC721: id not found")

    expect(await this.wrapped.totalSupply()).to.equal(0)
  })

  it("should emit mint and burn events", async function () {
    await expect(this.wrapped.connect(this.alpha).mint(this.omega.address, "0x00", 1))
      .to.emit(this.wrapped, "MintSingle")
      .withArgs(this.alpha.address, this.omega.address, "0x00", 1, 2)

    await expect(this.wrapped.connect(this.beta).batchMint(this.omega.address, ["0x01", "0x02", "0x03", "0x04", "0x05"], [1, 1, 1, 1, 1]))
      .to.emit(this.wrapped, "MintBatch")
      .withArgs(this.beta.address, this.omega.address, ["0x01", "0x02", "0x03", "0x04", "0x05"], [1, 1, 1, 1, 1], 10)

    await this.wrapped.connect(this.omega).approve(this.omega.address, 12)

    await expect(this.wrapped.connect(this.omega).burn(this.omega.address, this.alpha.address, 1))
      .to.emit(this.wrapped, "BurnSingle")
      .withArgs(this.omega.address, this.alpha.address, "0x05", 1, 2)

    await expect(this.wrapped.connect(this.omega).batchBurn(this.omega.address, this.beta.address, [1, 1]))
      .to.emit(this.wrapped, "BurnBatch")
      .withArgs(this.omega.address, this.beta.address, ["0x04", "0x03"], [1, 1], 4)

    await expect(this.wrapped.connect(this.omega).idBurn(this.omega.address, this.alpha.address, "0x02", 1))
      .to.emit(this.wrapped, "BurnSingle")
      .withArgs(this.omega.address, this.alpha.address, "0x02", 1, 2)

    await expect(this.wrapped.connect(this.omega).batchIdBurn(this.omega.address, this.beta.address, ["0x01", "0x00"], [1, 1]))
      .to.emit(this.wrapped, "BurnBatch")
      .withArgs(this.omega.address, this.beta.address, ["0x01", "0x00"], [1, 1], 4)
  })

  it("should fail on mint/burn without tokens", async function () {
    await expect(this.wrapped.connect(this.alpha).mint(this.alpha.address, "0xff", 1))
      .to.be.revertedWith("ERC721: operator query for nonexistent token")

    await expect(this.wrapped.connect(this.alpha).batchMint(this.alpha.address, ["0xff"], [1]))
      .to.be.revertedWith("ERC721: operator query for nonexistent token")

    await expect(this.wrapped.connect(this.alpha).burn(this.alpha.address, this.alpha.address, 1))
      .to.be.revertedWith("WrappedERC721: pool is empty")

    await expect(this.wrapped.connect(this.alpha).idBurn(this.alpha.address, this.alpha.address, "0xff", 1))
      .to.be.revertedWith("WrappedERC721: id not found")

    await expect(this.wrapped.connect(this.alpha).batchBurn(this.alpha.address, this.alpha.address, [1]))
      .to.be.revertedWith("WrappedERC721: amounts are greater than pool size")

    await expect(this.wrapped.connect(this.alpha).batchIdBurn(this.alpha.address, this.alpha.address,["0xff"],  [1]))
      .to.be.revertedWith("WrappedERC721: id not found")
  })

  it("should supply token transfers properly", async function () {
    await this.wrapped.connect(this.alpha).mint(this.omega.address, "0x00", 1)
    await this.wrapped.connect(this.omega).transfer(this.alpha.address, 2);

    expect(await this.wrapped.totalSupply()).to.equal(2)
    expect(await this.wrapped.balanceOf(this.alpha.address)).to.equal(2)
    expect(await this.wrapped.balanceOf(this.beta.address)).to.equal(0)
    expect(await this.wrapped.balanceOf(this.omega.address)).to.equal(0)
  })
})
