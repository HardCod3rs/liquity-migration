pragma solidity ^0.5.17;

interface IProxyRegistery {
    function build(address owner) external returns (DSProxy proxy);
}

interface IGuardRegistery {
    function newGuard(address guardOwner) external returns (DSGuard guard);
}

interface DSGuard {
    function permit(
        address src,
        address dst,
        bytes32 sig
    ) external;

    function setOwner(address owner_) external;
}

contract DSAuthority {
    function canCall(
        address src,
        address dst,
        bytes4 sig
    ) public view returns (bool);
}

interface DSProxy {
    function owner() external view returns (address);

    function execute(address _target, bytes calldata _data) external payable returns (bytes32 response);

    function setAuthority(DSAuthority authority_) external;

    function setOwner(address owner_) external;
}
