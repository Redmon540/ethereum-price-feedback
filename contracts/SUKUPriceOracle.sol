// SPDX-License-Identifier: MIT
pragma solidity >0.5.16;

import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/UniswapPriceOracleInterface.sol";
import "./interfaces/CTokenInterfaces.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SUKUPriceOracle {
    using SafeMath for uint256;
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;
    uint256 constant MANTISSA_DECIMALS = 18;

    AggregatorV3Interface internal priceFeedETHUSD;
    AggregatorV3Interface internal priceFeedUSDCETH;
    UniswapPriceOracleInterface internal uniswapPriceOracle;

    constructor(
        address priceFeedETHUSD_,
        address priceFeedUSDCETH_,
        address uniswapPriceOracle_
    ) public {
        priceFeedETHUSD = AggregatorV3Interface(priceFeedETHUSD_);
        priceFeedUSDCETH = AggregatorV3Interface(priceFeedUSDCETH_);
        uniswapPriceOracle = UniswapPriceOracleInterface(uniswapPriceOracle_);
    }

    /**
     * @notice Get the current price of a supported cToken underlying
     * @param cToken The address of the market (token)
     * @return USD price mantissa or failure for unsupported markets
     */
    function getUnderlyingPrice(address cToken) public view returns (uint256) {
        string memory cTokenSymbol = CTokenInterface(cToken).symbol();
        // sETH doesn't not have an underlying field
        if (compareStrings(cTokenSymbol, "sETH")) {
            return getETHUSDCPrice();
        }
        address underlyingAddress = CErc20Interface(cToken).underlying();
        uint underlyingDecimals = Erc20Interface(underlyingAddress).decimals();
        // Becuase decimals places differ among contracts it's necessary to
        //  scale the price so that the values between tokens stays as expected
        uint256 priceFactor = MANTISSA_DECIMALS.sub(underlyingDecimals);
        if (compareStrings(cTokenSymbol, "sUSDC")) {
            return
                getETHUSDCPrice()
                    .mul(getUSDCETHPrice())
                    .div(10**MANTISSA_DECIMALS)
                    .mul(10**priceFactor);
        } else if (compareStrings(cTokenSymbol, "sSUKU")) {
            uint256 SUKUETHpriceMantissa =
                uniswapPriceOracle.consult(
                    address(CErc20Interface(address(cToken)).underlying())
                );
            return
                getETHUSDCPrice()
                    .mul(SUKUETHpriceMantissa)
                    .div(10**MANTISSA_DECIMALS)
                    .mul(10**priceFactor);
        } else {
            revert("This is not a supported market address.");
        }
    }

    /**
     * @notice Get the ETHUSD price from ChainLink and convert to a mantissa value
     * @return USD price mantissa
     */
    function getETHUSDCPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedETHUSD.latestRoundData();
        // Get decimals of price feed
        uint256 decimals = priceFeedETHUSD.decimals();
        // Add decimal places to format an 18 decimal mantissa
        uint256 priceMantissa =
            uint256(price).mul(10**(MANTISSA_DECIMALS.sub(decimals)));

        return priceMantissa;
    }

    /**
     * @notice Get the USDCETH price from ChainLink and convert to a mantissa value
     * @return USD price mantissa
     */
    function getUSDCETHPrice() public view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeedUSDCETH.latestRoundData();
        // Get decimals of price feed
        uint256 decimals = priceFeedUSDCETH.decimals();
        // Add decimal places to format an 18 decimal mantissa
        uint256 priceMantissa =
            uint256(price).mul(10**(MANTISSA_DECIMALS.sub(decimals)));

        return priceMantissa;
    }

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
