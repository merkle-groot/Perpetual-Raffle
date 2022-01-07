#!/usr/bin/python3
from brownie import Raffle, RaffleNFT, config, network
from scripts.helpful_scripts import (
    get_account
)

def main():
    raffleNFT = RaffleNFT[-1]
    raffle = Raffle[-1]

    raffleNFT.sendToRaffle(
        raffle.address,
        1,
        "https://gateway.pinata.cloud/ipfs/QmZoWau9PQmNHByfQCfLteHPm3fMywgqmMGjmCRG5EQDUN",
        {"from": get_account()}
    )

