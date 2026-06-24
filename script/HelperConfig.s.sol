//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.t.sol";

abstract contract CodeConstant {
    uint256 public constant ENTERANCE_FEE = 0.001 ether;
    uint256 public constant SEPOLIA_CHAIN = 11155111;
    uint256 public constant INTERVAL = 86400 seconds;
    uint256 public constant LOCAL_CHAIN = 31337;
    uint96 public constant BASE_FEE = 0.1 ether;
    uint96 public constant GAS_PRICE = 1e9;
    int256 public constant WEI_PER_UINT_LINK = 0.0001 ether;
    uint32 public constant CALL_BACK_GAS_LIMIT = 500000;
    address public immutable SEPOLIA_ACCOUNT = 0x550C6209A27ac49f6867ad833f6b358DFFa38F0E;
    address public immutable SEPOLIA_VRF_COORDINATOR = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 public immutable SEPOLIA_KEYHASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 public constant SEPOLIA_SUBSCRIPTIONID =
        57956206108502245417081721518091069483609105349517626183960896263760141501054;
    address public immutable SEPOLIA_LINK_ADDRESS = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address public immutable ANVIL_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    bytes32 public immutable ANVIL_KEYHASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 public constant ANVIL_SUBSCRIPTIONID = 0;
}

contract HelperConfig is Script, CodeConstant {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 enteranceFee;
        address account;
        uint256 interval;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    mapping(uint256 chainId => NetworkConfig) public networkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN) {
            networkConfig[SEPOLIA_CHAIN] = getSepoliaEthConfig();
        } else {
            networkConfig[LOCAL_CHAIN] = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            enteranceFee: ENTERANCE_FEE,
            account: SEPOLIA_ACCOUNT,
            interval: 30 seconds,
            vrfCoordinator: SEPOLIA_VRF_COORDINATOR,
            keyHash: SEPOLIA_KEYHASH,
            subscriptionId: SEPOLIA_SUBSCRIPTIONID,
            callbackGasLimit: CALL_BACK_GAS_LIMIT,
            link: SEPOLIA_LINK_ADDRESS
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfig[LOCAL_CHAIN].vrfCoordinator != address(0)) {
            return networkConfig[LOCAL_CHAIN];
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE, WEI_PER_UINT_LINK);

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        return NetworkConfig({
            enteranceFee: ENTERANCE_FEE,
            account: ANVIL_ACCOUNT,
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinator),
            keyHash: ANVIL_KEYHASH,
            subscriptionId: ANVIL_SUBSCRIPTIONID,
            callbackGasLimit: CALL_BACK_GAS_LIMIT,
            link: address(linkToken)
        });
    }

    function getConfigByChainId(uint256 chainId) private view returns (NetworkConfig memory) {
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() external view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
