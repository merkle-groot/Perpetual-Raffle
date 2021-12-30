#!/usr/bin/python3
from brownie import Raffle, RaffleNFT, config, network
from scripts.helpful_scripts import (
    get_account,
    get_contract,
)


def main():
    account = get_account()
    print(f"On network {network.show_active()}")
    keyhash = config["networks"][network.show_active()]["keyhash"]
    fee = config["networks"][network.show_active()]["fee"]
    vrf_coordinator = get_contract("vrf_coordinator")
    link_token = get_contract("link_token")
    treasury_role = '0xCbb97e458b8EAdb1A1c63b917B3F330FE8bd2aC9'
    treasury = '0xc9AcC39D037E87E9754609b201Acc2B34eB9008c'
    slot_price = '0.001 ether'
    max_slots = 100000

    nft = RaffleNFT.deploy(
        {"from": get_account()}
    )
    print(nft)

    raffle = Raffle.deploy(
        treasury_role,
        treasury,
        nft.address,
        slot_price,
        keyhash,
        vrf_coordinator,
        link_token,
        fee,
        max_slots,
        {"from": account},
    )

    print(raffle)