pragma solidity >=0.6.0 <0.7.0;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  ExampleExternalContract public exampleExternalContract;

  mapping ( address => uint256 ) public balances;
  
  uint256 public constant threshold = 10 ether;

  uint256 public deadline = now + 1440 minutes;

  bool public openForWithdraw = false;

  event Stake(address addr, uint256 amount);

  constructor(address exampleExternalContractAddress) public {
    exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  modifier notCompleted() {
    require(!exampleExternalContract.completed(), 'ExampleExternalContract has completed');
    _;
  }

  modifier deadlineNotReached() {
    require(timeLeft() > 0, 'Deadline reached');
    _;
  }

  modifier deadlineReached() {
    require(timeLeft() == 0, 'Deadline not reached');
    _;
  }

  modifier notOverThreshold() {
    require(address(this).balance <= threshold, "Balance over threshold");
    _;
  }

  // Collect funds in a payable `stake()` function and track individual `balances` with a mapping:
  //  ( make sure to add a `Stake(address,uint256)` event and emit it for the frontend <List/> display )
  function stake() public deadlineNotReached notOverThreshold notCompleted payable {
    balances[msg.sender] += msg.value;

    if (address(this).balance >= threshold) {
      exampleExternalContract.complete{value: address(this).balance}();
    }

    emit Stake(msg.sender, msg.value);
  }

  // After some `deadline` allow anyone to call an `execute()` function
  //  It should either call `exampleExternalContract.complete{value: address(this).balance}()` to send all the value
  function execute() public deadlineReached {
    if (address(this).balance >= threshold) {
      exampleExternalContract.complete{value: address(this).balance}();
    } else {
      openForWithdraw = true;
    }
  }

  // if the `threshold` was not met, allow everyone to call a `withdraw()` function
  function withdraw(address payable addr) public deadlineReached notCompleted {
    require(msg.sender == addr, "Can only withdraw your staked ether");
    require(openForWithdraw, "Withdraw is not open");

    uint256 amount = balances[addr];

    (bool sent, ) = addr.call{value: amount}("");
    require(sent, "Failed to withdraw balances");
    balances[addr] = 0;
  }


  // Add a `timeLeft()` view function that returns the time left before the deadline for the frontend
  function timeLeft() public view returns(uint256) {
    if (now >= deadline) {
      return 0;
    }
    return deadline - now;
  }

  // Add the `receive()` special function that receives eth and calls stake()
  receive() external payable {
    stake();
  }

  function totalBalance() public view returns (uint256) {
    return address(this).balance;
  }

}
