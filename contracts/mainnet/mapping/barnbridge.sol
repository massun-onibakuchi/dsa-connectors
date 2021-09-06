pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IndexInterface {
    function master() external view returns (address);
}

interface ConnectorsInterface {
    function chief(address) external view returns (bool);
}

interface IProvider {
    function smartYield() external view returns (address);    
    function uToken() external view returns (address);
    function cToken() external view returns (address);
}

abstract contract Helpers {

    struct TokenMap {
        address token;
        address ctoken;
        address smartYield;
    }

    event LogCTokenAdded(string indexed name, address indexed token, address indexed ctoken);
    event LogCTokenUpdated(string indexed name, address indexed token, address indexed ctoken);

    ConnectorsInterface public immutable connectors;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping (string => TokenMap) public cTokenMapping;

    modifier isChief {
        require(msg.sender == instaIndex.master() || connectors.chief(msg.sender), "not-an-chief");
        _;
    }

    constructor(address _connectors) {
        connectors = ConnectorsInterface(_connectors);
    }

    function _addCtokenMapping(
        string[] memory _names,
        address[] memory _smartYields,
        address[] memory _providers
    ) internal {
        require(_names.length == _smartYields.length, "addCtokenMapping: not same length");
        require(_names.length == _providers.length, "addCtokenMapping: not same length");

        for (uint i = 0; i < _providers.length; i++) {
            TokenMap memory _data = cTokenMapping[_names[i]];

            require(_data.ctoken == address(0), "addCtokenMapping: mapping added already");
            require(_data.token == address(0), "addCtokenMapping: mapping added already");

            require(_smartYields[i] != address(0), "addCtokenMapping: _smartYields address not vaild");
            require(_providers[i] != address(0), "addCtokenMapping: _providers address not vaild");

            IProvider _provider = IProvider(_providers[i]);
            if (_smartYields[i] != ethAddr) {
                require(_provider.smartYield() == _smartYields[i],"mapping mismatch");
            }

            cTokenMapping[_names[i]] = TokenMap(
                _provider.cToken(),
                _provider.uToken(),
                _smartYields[i]
            );
            emit LogCTokenAdded(_names[i], _smartYields[i], _providers[i]);
        }
    }

    function updateCtokenMapping(
        string[] calldata _names,
        address[] memory _smartYields,
        address[] memory _providers
    ) external {
        require(msg.sender == instaIndex.master(), "not-master");

        require(_names.length == _smartYields.length, "updateCtokenMapping: not same length");
        require(_names.length == _providers.length, "updateCtokenMapping: not same length");

        for (uint i = 0; i < _providers.length; i++) {
            TokenMap memory _data = cTokenMapping[_names[i]];

            require(_data.ctoken != address(0), "updateCtokenMapping: mapping does not exist");
            require(_data.token != address(0), "updateCtokenMapping: mapping does not exist");

            require(_smartYields[i] != address(0), "updateCtokenMapping: _smartYields address not vaild");
            require(_providers[i] != address(0), "updateCtokenMapping: _providers address not vaild");

            IProvider _provider = IProvider(_providers[i]);

            if (_smartYields[i] != ethAddr) {
                require(_provider.smartYield() == _smartYields[i], "addCtokenMapping: mapping mismatch");
            }

            cTokenMapping[_names[i]] = TokenMap(
                _provider.uToken(),
                _provider.cToken(),
                _smartYields[i]
            );
            emit LogCTokenUpdated(_names[i], _smartYields[i], _providers[i]);
        }
    }

    function addCtokenMapping(
        string[] memory _names,
        address[] memory _smartYields,
        address[] memory _providers
    ) external isChief {
        _addCtokenMapping(_names, _smartYields, _providers);
    }

    function getMapping(string memory _tokenId) external view returns (address, address, address) {
        TokenMap memory _data = cTokenMapping[_tokenId];
        return (_data.token, _data.ctoken, _data.smartYield);
    }

}

contract InstaBarnBridgeSmartYieldMapping is Helpers {
    string constant public name = "BarnBridgeSmartYield-Mapping-v1.0";

    constructor(
        address _connectors,
        string[] memory _ctokenNames,
        address[] memory _tokens,
        address[] memory _ctokens
    ) Helpers(_connectors) {
        _addCtokenMapping(_ctokenNames, _tokens, _ctokens);
    }
}