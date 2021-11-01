from pathlib import WindowsPath
from brownie import DappToken, TokenFarm, config, network
from brownie.network.web3 import Web3
from scripts.helpful_scripts import get_account, get_contract
import yaml
import json
import os
import shutil

KEPT_BALANCE = Web3.toWei(100, 'ether')

def deploy_token_and_farm(front_end_update = False):
    account = get_account()
    dapp_token = DappToken.deploy({"from": account})
    token_farm = TokenFarm.deploy(dapp_token.address, {"from": account}, publish_source = config["networks"][network.show_active()].get("verify",False))
    tx = dapp_token.transfer(token_farm.address, dapp_token.totalSupply() - KEPT_BALANCE, {"from": account})
    tx.wait(1)
    # allowed_token_dic,dapp_token, weth_token, dai_token, price_feed
    weth_token = get_contract("weth_token")
    dai_token = get_contract("dai_token")
    dict_of_allowed_tokens = {
        dapp_token: get_contract("dai_usd_price_feed"),
        dai_token: get_contract("dai_usd_price_feed"),
        weth_token: get_contract("eth_usd_price_feed")
    }
    add_allowed_token(token_farm, dict_of_allowed_tokens,account)
    if front_end_update:
        update_front_end()
    return token_farm, dapp_token


def add_allowed_token(token_farm, dict_of_allowed_tokens, account):
    # loop all tokens in dict
    for token in dict_of_allowed_tokens:
        add_tx = token_farm.addAllowedTokens(token.address, {"from": account})
        add_tx.wait(1)
        # address _token, address _priceFeed
        set_tx = token_farm.setPriceFeedContract(token.address, dict_of_allowed_tokens[token], {"from": account})
        set_tx.wait(1)
    return token_farm

def update_front_end():
    # send the build folder
    copy_floders_to_front_end('./build', './front_end/src/chain-info')
    # send config info as json to front end
    with open("brownie-config.yaml", 'r') as brownie_config:
        config_dict = yaml.load(brownie_config, Loader=yaml.FullLoader)
        with open("./front_end/src/brownie-config.json", 'w') as brownie_config_json:
            json.dump(config_dict, brownie_config_json)
    print("Updated front end!")

def copy_floders_to_front_end(src, dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(src, dest)

def main():
    deploy_token_and_farm(front_end_update=True)
