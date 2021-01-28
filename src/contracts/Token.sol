/**
    Scrap code, possibly used for protocol token in the future.
 */
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    function name() public view returns (string) 
    function symbol() public view returns (string)
    function decimals() public view returns (uint8)
    function totalSupply() public view returns (uint256)
    function balanceOf(address _owner) public view returns (uint256 balance)
    function transfer(address _to, uint256 _value) public returns (bool success)
}