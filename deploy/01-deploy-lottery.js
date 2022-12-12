const { network, ethers } = require("hardhat")
const {
    networkConfig,
    developmentChains,
    VERIFICATION_BLOCK_CONFIRMATIONS,
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")
//юс╫ц

const VRF_SUB_FUND_AMOUNT = ethers.utils.parseEther("2")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainID = network.config.chainID

    let vrfCoordinatorV2Address, subscriptionID

    if (developmentChains.includes(network.name)) {
        const vrfCoordinatorV2Mock = await ethers.getContract(
            "VRFCoordinatorV2Mock"
        )
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        //
        const transactionRespone =
            await vrfCoordinatorV2Mock.createSubscription()
        const transactionReceipt = await transactionRespone.wait(1)

        subscriptionID = transactionReceipt.events[0].args.subId

        //Fund subcription
        //need to link to real network... which i don`t have
        await vrfCoordinatorV2Mock.fundSubscription(
            subscriptionID,
            VRF_SUB_FUND_AMOUNT
        )
    } else {
        vrfCoordinatorV2Address = networkConfig[chainID]["vrfCoordinatorV2"]
        subscriptionID = networkConfig[chainID]["subscriptionID"]
    }

    console.log(chainID)
    const entranceFee = networkConfig[chainID]["entranceFee"]
    const gasLane = networkConfig[chainID]["gasLane"]
    const callbackGasLimit = networkConfig[chainID]["callbackGasLimit"]
    const interval = networkConfig[chainID]["interval"]

    const args = [
        vrfCoordinatorV2Address,
        entranceFee,
        gasLane,
        subscriptionID,
        callbackGasLimit,
        interval,
    ]

    // console.log(args)
    const lottery = await deploy("Lottery", {
        from: deployer,
        args: args,
        log: true,
        waitConfrimation: network.config.blockConfirmations || 1,
    })

    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("verifying.......")
        await verify(lottery.address.args)
    }
    log("......................................................")
}

module.exports.tags = ["all", "lottery"]
