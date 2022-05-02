// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <=0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GovernanceUpgradeable is Initializable, ContextUpgradeable {

    address public _governance;

    function __GovernanceUpgradeable_init() internal onlyInitializing {
        __GovernanceUpgradeable_init_unchained();
    }

    function __GovernanceUpgradeable_init_unchained() internal onlyInitializing {
        _governance = msg.sender;
    }

    event GovernanceTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyGovernance {
        require(msg.sender == _governance, "not governance");
        _;
    }

    function setGovernance(address governance)  public  onlyGovernance
    {
        require(governance != address(0), "new governance the zero address");
        emit GovernanceTransferred(_governance, governance);
        _governance = governance;
    }


}