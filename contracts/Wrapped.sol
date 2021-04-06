pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title Wrapped 
 * @dev Token which wraps Wrappable
 */
abstract contract Wrapped is ERC20Capped {

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal virtual override(ERC20, ERC20Capped) {
    //     super._beforeTokenTransfer(from, to, amount);
    // }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 _allowance = allowance(account, _msgSender());
        require(_allowance >= amount, "ERC20: burn amount exceeds allowance");
        uint256 decreasedAllowance = _allowance - amount;

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
}

