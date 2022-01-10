import React, { useEffect, useState } from 'react';
import {Table, Button} from "react-bootstrap";
import Web3 from 'web3';
import RaffleJSON  from "../Raffle.json";

import "./Dashboard.css";

  
const Dashboard = () => {
	
	const [account, setAccount] = useState(0);
	const [Raffle, setRaffle] = useState();
	const [maxSlots, setMaxSlots] = useState(0);
	const [availableSlots, setAvailableSLots] = useState(0);
	const [slotFee, setSlotFee] = useState(0);
	const [noOfRounds, setNoOfRounds] = useState(0);
	const [currentPhase, setCurrentPhase] = useState(-2);
	const [nftID, setNftID] = useState(-1);
	const [userOwned, setUserOwned] = useState({
	  	EnteredRound: "-1",
		noOfSlots: "-1",
		noOfSlotsBought: "-1"
	});
	const [slotsToBuy, setSlotsToBuy] = useState(0);
	const [slotsToRefund, setSlotsToRefund] = useState(0);
	const [provider, setProvider] = useState();
	
	const buySlots = async() => {
		const currentPhaseResult = await Raffle.methods.currentPhase().call();
		console.log(currentPhaseResult);
		if(currentPhaseResult != 0){
			alert("Can't purchase during this phase!");
		}
		const userBalance = await provider.eth.getBalance(account);
		const slotPrice = await Raffle.methods.slotPrice().call();
		
		const cost = slotPrice * slotsToBuy;
		if(cost >= userBalance){
			alert(`Insufficient balance to buy ${slotsToBuy} amount of slots!`);
		} else {
			const result = await  Raffle.methods.purchaseSlot(slotsToBuy, 0).send({
				from: account,
				value: cost
			})
			console.log(result);
		}
	}

	const refundSlots = async() => {
		const currentPhaseResult = await Raffle.methods.currentPhase().call();
		if(currentPhaseResult != 0){
			alert("Can't refund during this phase!");
		}
		const slotOwners = await Raffle.methods.getSlotOwners().call();
		console.log(slotOwners);
		
		let userOwnedSlots = [];
		slotOwners.forEach((address, index) => {
			if(address === account)
				userOwnedSlots.push(index);
		});

		const slotsToDelete = userOwnedSlots.slice(0, slotsToRefund);
		const result = await Raffle.methods.refundSlot(slotsToDelete).send({
			from:account
		});
		console.log(result);
	}

	const freeSlots = async() => {
		const currentPhaseResult = await Raffle.methods.currentPhase().call();
		if(currentPhaseResult != 0){
			alert("Can't ask for free slots during this phase!");
		}
		const userData = Raffle.methods.addressToSlotsOwner(account).call();
		const noOfRounds = Raffle.methods.noOfRounds().call();

		if(userData.enteredRound == noOfRounds){
			alert("Wait till the next Round to get free slots!");
		}

		const maxFreeSlots = parseInt(userData.noOfSlotsBought/10) + 1
		const result = await Raffle.methods.purchaseSlot((userData.noOfSlotsBought/10) + 1, 1).send({
			from:account
		});
		console.log(result);
	}

	const load = async(web3, RaffleContract, accounts) => {

		const maxSlotsResult = await RaffleContract.methods.numSlotsAvailable().call();
		setMaxSlots(maxSlotsResult);

		const slotFeeResult = await RaffleContract.methods.slotPrice().call();
		const etherValue = web3.utils.fromWei(slotFeeResult, 'ether');
		setSlotFee(etherValue);

		const noOfRoundsResult = await RaffleContract.methods.noOfRounds().call();
		setNoOfRounds(noOfRoundsResult);

		const currentPhaseResult = await RaffleContract.methods.currentPhase().call();
		setCurrentPhase(currentPhaseResult);

		const filledSlots = await RaffleContract.methods.numSlotsFilled().call();
		setAvailableSLots(maxSlotsResult - filledSlots);

		const nftIDResult = await RaffleContract.methods.nftID().call();
		setNftID(nftIDResult);

		const userOwnedResult = await RaffleContract.methods.addressToSlotsOwner(accounts[0]).call();
		console.log(userOwnedResult);
		setUserOwned(userOwnedResult);
	}

  	useEffect(async() => {
		const web3 = new Web3(Web3.givenProvider);
		setProvider(web3);
		const accounts = await web3.eth.requestAccounts();
		setAccount(accounts[0]);

		const chainId = await web3.eth.getChainId();
		console.log(chainId);
		if(chainId != 42){
			alert("Please switch your network to Kovan Testnet!");
		}

		web3.eth.defaultChain = "kovan";
		const RaffleContract = new web3.eth.Contract(RaffleJSON.abi, "0xb396B1E0f0d6Eb1eBE2b059077313a68A9b78e71");
		setRaffle(RaffleContract);


		RaffleContract.events.SlotsClaimed({})
			.on('data', async function(event){
				console.log(event.returnValues);
				load(web3, RaffleContract, accounts);
			})
			.on('error', console.error);

		console.log(RaffleContract)

		RaffleContract.events.SlotsRefunded({})
			.on('data', async function(event){
				console.log(event.returnValues);
				load(web3, RaffleContract, accounts);
			})
			.on('error', console.error);

		console.log(RaffleContract)

    	load(web3, RaffleContract, accounts);
  	}, []);

	return(
		<div className="dashboard">
				<div className="canvas">
				<div className="imageCard card">
					<img alt="nftImage" src={"https://gateway.pinata.cloud/ipfs/QmZoWau9PQmNHByfQCfLteHPm3fMywgqmMGjmCRG5EQDUN"} className="artistImage"/>
				</div>
				
				<div className="deetsCard card">
					<Table striped bordered hover>
						<tbody>
							<tr>
								<td>NFT ID of current round of Perp* Raffle: </td>
								<td>{nftID==-1?"loading":nftID}</td>
							</tr>
							<tr>
								<td>Total Number of Slots</td>
								<td>{maxSlots==0?"loading":maxSlots}</td>
							</tr>

							<tr>
								<td>Total number of slots available to be Bought</td>
								<td>{availableSlots==0?"loading":availableSlots}</td>
							</tr>
							<tr>
								<td>Cost of a Single Slot in this Perp* Raffle</td>
								<td>{slotFee==0?"loading":slotFee} Ether</td>
							</tr>
							<tr>
								<td>Total Number of Rounds in this Perp* Raffle</td>
								<td>{noOfRounds==-1?"loading":noOfRounds}</td>
							</tr>
							<tr>
								<td>The current phase of the Perp* Raffle in this Round</td>
								<td>{currentPhase==-2?"loading":currentPhase}</td>
							</tr>
							<tr>
								<td>Currently, You own </td>
								<td>{userOwned.noOfSlotsBought==-1?"loading":userOwned.noOfSlotsBought}</td>
							</tr>

						</tbody>
					</Table>
					<span className="buttonArea">
						<input value={slotsToBuy} type="number" min="0" max={availableSlots} onChange={(e)=>setSlotsToBuy(e.target.value)}/> 
						<Button variant="success" onClick={()=>buySlots()}>Buy Slots </Button>
					</span>

					<span className="buttonArea">
						<input value={slotsToRefund} type="number" min="0" max={userOwned} onChange={(e)=>setSlotsToRefund(e.target.value)}/> 
						<Button variant="warning" onClick={()=>refundSlots()}>Refund Slots</Button>
					</span>

					<span className="buttonArea Free">
						<Button variant="secondary" onClick={()=>freeSlots()}>Get Free Slots</Button>
					</span>
				</div>
			</div>
		</div>
	);
};

export default Dashboard;