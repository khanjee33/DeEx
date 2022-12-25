// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import  "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    //Exchange is inherting ERC20 because our exchange would keep track of crypto Dev LP tokens
    constructor (address _CryptoDevToken) ERC20("CryptoDev  LP Token","CDLP"){
        require(_CryptoDevToken != address(0),"Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    } 

    /**
    @dev Returns the amount of Crypto Dev Tokens held by the contract
     */
     function  getReserve() public view returns (uint){
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
     }

     /**
     @dev adds liquidity to the exchange
      */
      function addLiquidity(uint  _amount) public payable returns (uint){
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint  cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        /**
    if the reserve is empty,initiate any user supplied vlue for 
    'Ether' and 'crypto Dev tokens because there is no ratio currently
     */
        if (cryptoDevTokenReserve  == 0){
            // Transfer the 'cryptoDevToken from the user's account to the contract
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            // take the current ethBalance and mint ethBalance amoubnt of LP tokens to the user
            // liquidity provider is equal to 'ethBalance because this is the first time user
            // is adding 'ETH' to the contract so whatever 'ETH' contract has is equal to the one supplied
            // by the user in the current addLiquidity call
            // liquidity tokens that need to be minted to the user on addLiquidity
            // to the ETH specified by the user
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
            // _mint is ERC20.sol smart contract function to mint ERC20 tokens
        }else{
            /**
            if the reserve is not empty intake any user supplied value fo 
            'ether and determine according to the ratio how many Crypto Dev tokens
            need to be supplied to prevent any large price impacts because of the additional
            liquidity
             */
             // EtherReserve should be the current ethBalance subtracted by the value of the ether sent by the user
             // in the current addLiquidity call
             uint ethReserve = ethBalance - msg.value;
             // ratio should always be maintained so that there are no major price impacts wheb adding liquidity
             // Ratio here is -> (cryptoDevTokenAmount user can add) = (Eth sent by the user * cryptoDevTokenReserve/eth reserve);
             // so doing some maths (cryptoDevTokenAmount user can add )= (eth sent by the user * cryptoDevTokenReserve /Eth Reserve);
            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve)/(ethReserve);
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minimum tokens required");
            // transfer only (cryptoDevTokenAmount user can add) amount of crypto dev tokens from users account
            // to the contract
            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);
            // the amount of LP tokens that would be sent to the user should be propotional to the liqquiidity of 
            // ehter added by the user 
            // ratio here to be maintained is ->
            // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (ETh sent by the user)/(Eth reserve in the contract) 
            // by some maths -> liquidity = (totalSupply of LP tokens in contract * (eth sent by the user))/(eth reserve in the contract)
            liquidity = (totalSupply()* msg.value)/ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;

    }
    /**
    @dev returns the amount ETH/Crpto Dev tokens that would be returned to the user
    in the swap
     */
     function removalLiquidity(uint _amount) public returns(uint, uint) {
        require(_amount > 0, "_amount should be greater than zero");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();
        // the amount of eth that would be sent back to the user is based
        // on a ratio
        // ratio is -> (eth sent back to the user)/ (current eth reserve)
        // = (amount of LP tokens that user wants to withdraw)/(total supply of LP tokens)
        // then by some maths -> (Eth sent back to the user)
        // = (current ETH reserve * amount of LP tokens that user wants to withdraw)/(total supply of LP tokens)
        uint ethAmount = (ethReserve * _amount)/ _totalSupply;
        // the amount of Crypto Dev token that would be sent back to the user is based
        // on a ratio
        // ratio is -> (Crypto Dev sent back to the user)/(current Crypto Dev token reserve)
        // = (amount of LP tokens that user wants to withdraw)/(total supply of LP tokens)
        // then by some maths -> (Crypto dev sent back to the user)
        // = (current Crypto Dev tokeb reserve * amount of LP tokens that user wants to withdraw)/(total supplu of LP tokens)
        uint cryptoDevTokenAmount = (getReserve()* _amount)/_totalSupply;
        // burn the sent LP tokens from the user's wallet because they are already sent to 
        // remove liquidity
        _burn(msg.sender, _amount);
        payable(msg.sender).transfer(ethAmount);
        // transfer cryptoDevtoken of Crypto dev tokens from the contract to teh user wallet
        ERC20(cryptoDevTokenAddress).transfer(msg.sender,cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
        
     }
     /**
     @dev Returns the amount ETH/Crypto Dev tokens that would be returned to the user
     in the swap 
     */
     function getAmountOfTokens(
        uint256 inpuptAmount,
        uint256 inputReserve,
        uint256 outputReserve
     ) public pure returns (uint256){
        require(inputReserve > 0 && outputReserve > 0 , "invalid reserve");
        // we are charging a fee of 1%
        // input amount with fee = (input amount - (1*(input amount)/100))=((input amount)*99)/100
        uint256 inpuptAmountWithFee = inpuptAmount * 99;
        // because we need to follow the concept of 'XY=K curve
        // we need to make sure (x+ Δx) * (y - Δy) = x * y
        //so the final formula is Δy = (y *Δx)/(x +Δx)
        // Δy in our cas is tokens to be recieved
        // Δx = ((input amount)*99)/100 x = inputReserve, y =outputReserve
        // sso by putting the values in the formula you can get the numerator and denominator
        uint256 numerator = inpuptAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100)+ inpuptAmountWithFee;
        return numerator/denominator;
     }
    /**
    @dev swaps ETH for Crypto tokens
     */
     function ethToCryptoDevToken(uint _mintTokens)public payable{
        uint256 tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of Crypto Dev tokens
        // that would be returned to the user after the swap
        // Notice that the `inputReserve` we are sending is equal to
        // `address(this).balance - msg.value` instead of just `address(this).balance`
        // because `address(this).balance` already contains the `msg.value` user has sent in the given call
        // so we need to subtract it to get the actual input reserve

        uint256 tokensBought = getAmountOfTokens(
            msg.value, 
            address(this).balance - msg.value, 
            tokenReserve
            );
            require(tokensBought >= _mintTokens, "insufficient output amount");
            // transfer the Crypto Dev tokens to the user
            ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);

     }
    /**
    @dev swaps CryptoDev Tokens for ETH 
     */
     function cryptoDevTokenToEth(uint _tokenSold, uint _mintEth)public{
        uint256 tokenReserve = getReserve();
        // call the getAmountOfTokens to get the amount of Eth
        // that would be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokenSold, 
            tokenReserve, 
            address(this).balance
            );
            require(ethBought >= _mintEth, "Insufficient output amount");
            // Transfer Crypto Dev tokens from the user address to the contract
            ERC20(cryptoDevTokenAddress).transferFrom(
                msg.sender,
                address(this),
                _tokenSold
            );
            //send the ethBought to the user from the contract
            payable(msg.sender).transfer(ethBought);
     }    
    

}
