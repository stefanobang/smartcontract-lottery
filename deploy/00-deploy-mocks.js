const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //0.25 premium and 0.25 per transaction
const GAS_PRICE_LINK = 1e9 //calculating gas based ont he price

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    // const chainID = network.config.chainID

    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Local network is detected! This is a developing mock!")
        log(network.name)
        //deploying mock vrfcoordinator

        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mock deployed succesffully!!! :)")
        log("_____________________________________________")
    }
}

module.exports.tags = ["all", "mocks"]
