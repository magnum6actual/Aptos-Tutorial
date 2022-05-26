module TicketTutorial::Tickets {
    use Std::Signer;
	use Std::ASCII;
	use Std::Vector;
    use AptosFramework::TestCoin::TestCoin;
	use AptosFramework::Coin;
	use AptosFramework::Table::{Self, Table};
    use AptosFramework::ManagedCoin;

	struct SeatIdentifier has store, copy, drop {
		row: ASCII::String,
		seat_number: u64
	}

	struct ConcertTicket has key, store, drop {
		identifier: SeatIdentifier,
		ticket_code: ASCII::String,
		price: u64
	}

	struct Venue has key {
		available_tickets: Table<SeatIdentifier, ConcertTicket>,
		max_seats: u64
	}
	
	struct TicketEnvelope has key {
		tickets: vector<ConcertTicket>
	}

	const ENO_VENUE: u64 = 0;
	const ENO_TICKETS: u64 = 1;
	const ENO_ENVELOPE: u64 = 2;
	const EINVALID_TICKET_COUNT: u64 = 3;
	const EINVALID_TICKET: u64 = 4;
	const EINVALID_PRICE: u64 = 5;
	const EMAX_SEATS: u64 = 6;
	const EINVALID_BALANCE: u64 = 7;

	public(script) fun init_venue(venue_owner: &signer, max_seats: u64) {
		let available_tickets = Table::new<SeatIdentifier, ConcertTicket>();
		move_to<Venue>(venue_owner, Venue {available_tickets, max_seats})
	}

	public(script) fun create_ticket(venue_owner: &signer, row: vector<u8>, seat_number: u64, ticket_code: vector<u8>, price: u64) acquires Venue {
		let venue_owner_addr = Signer::address_of(venue_owner);
		assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
		let current_seat_count = available_ticket_count(venue_owner_addr);
		let venue = borrow_global_mut<Venue>(venue_owner_addr);
		assert!(current_seat_count < venue.max_seats, EMAX_SEATS);
		let identifier = SeatIdentifier { row: ASCII::string(row), seat_number };
		let ticket = ConcertTicket { identifier, ticket_code: (ASCII::string(ticket_code)), price};
		Table::add(&mut venue.available_tickets, &identifier, ticket)
    }

	public(script) fun available_ticket_count(venue_owner_addr: address): u64 acquires Venue {
		let venue = borrow_global<Venue>(venue_owner_addr);
		Table::length<SeatIdentifier, ConcertTicket>(&venue.available_tickets)
	}

	// fun get_ticket_info(venue_owner_addr: address, seat:vector<u8>): (bool, vector<u8>, u64, u64) acquires Venue {
	// 	assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
	// 	let venue = borrow_global<Venue>(venue_owner_addr);
	// 	let i = 0;
    //     let len = Vector::length<ConcertTicket>(&venue.available_tickets);
    //     while (i < len) {
	// 		let ticket= Vector::borrow<ConcertTicket>(&venue.available_tickets, i);
	// 		if (ticket.seat == seat) return (true, ticket.ticket_code, ticket.price, i);
    //         i = i + 1;
    //     };
	//     return (false, b"", 0, 0)
	// }

	// public(script) fun get_ticket_price(venue_owner_addr: address, seat:vector<u8>): (bool, u64) acquires Venue {
	// 	let (success, _, price, _) = get_ticket_info(venue_owner_addr, seat);
	// 	assert!(success, EINVALID_TICKET);
	// 	return (success, price)
	// }

	public(script) fun purchase_ticket(buyer: &signer, venue_owner_addr: address, row: vector<u8>, seat_number: u64) acquires Venue, TicketEnvelope {	
		let buyer_addr = Signer::address_of(buyer);	
		let target_seat_id = SeatIdentifier { row: ASCII::string(row), seat_number };
		let venue = borrow_global_mut<Venue>(venue_owner_addr);	
		assert!(Table::contains<SeatIdentifier, ConcertTicket>(&venue.available_tickets, &target_seat_id), EINVALID_TICKET);
		let target_ticket = Table::borrow<SeatIdentifier, ConcertTicket>(&venue.available_tickets, &target_seat_id);
		Coin::transfer<TestCoin>(buyer, venue_owner_addr, target_ticket.price);
		let ticket = Table::remove<SeatIdentifier, ConcertTicket>(&mut venue.available_tickets, &target_seat_id);
		if (!exists<TicketEnvelope>(buyer_addr)) {
			move_to<TicketEnvelope>(buyer, TicketEnvelope {tickets: Vector::empty<ConcertTicket>()});
		};	
		let envelope = borrow_global_mut<TicketEnvelope>(buyer_addr);
		Vector::push_back<ConcertTicket>(&mut envelope.tickets, ticket);
	}

	#[test(venue_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    public(script) fun sender_can_buy_ticket(venue_owner: signer, buyer: signer, faucet: signer) acquires Venue, TicketEnvelope {
		
		let venue_owner_addr = Signer::address_of(&venue_owner);

		// initialize the venue
		init_venue(&venue_owner, 3);
		assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);

		// create some tickets
		create_ticket(&venue_owner, b"A", 24, b"AB43C7F", 15);
		create_ticket(&venue_owner, b"A", 25, b"AB43CFD", 15);
		create_ticket(&venue_owner, b"A", 26, b"AB13C7F", 20);

		// verify we have 3 tickets now
		assert!(available_ticket_count(venue_owner_addr)==3, EINVALID_TICKET_COUNT);


		// initialize & fund account to buy tickets
        ManagedCoin::initialize<TestCoin>(&faucet, b"TestCoin", b"TEST", 6, false);
        ManagedCoin::register<TestCoin>(&faucet);
		ManagedCoin::register<TestCoin>(&venue_owner);
		ManagedCoin::register<TestCoin>(&buyer);
		
        let amount = 1000;
        let faucet_addr = Signer::address_of(&faucet);
        let buyer_addr = Signer::address_of(&buyer);
        ManagedCoin::mint<TestCoin>(&faucet, faucet_addr, amount);
        Coin::transfer<TestCoin>(&faucet, buyer_addr, 100);
        assert!(Coin::balance<TestCoin>(buyer_addr) == 100, EINVALID_BALANCE);

		// // buy a ticket and confirm account balance changes
		purchase_ticket(&buyer, venue_owner_addr, b"A", 24);
		assert!(exists<TicketEnvelope>(buyer_addr), ENO_ENVELOPE);
        assert!(Coin::balance<TestCoin>(buyer_addr) == 85, EINVALID_BALANCE);
		assert!(Coin::balance<TestCoin>(venue_owner_addr) == 15, EINVALID_BALANCE);
	    assert!(available_ticket_count(venue_owner_addr)==2, EINVALID_TICKET_COUNT);

		// buy a second ticket & ensure balance has changed by 20
		purchase_ticket(&buyer, venue_owner_addr, b"A", 26);
		assert!(Coin::balance<TestCoin>(buyer_addr) == 65, EINVALID_BALANCE);
		assert!(Coin::balance<TestCoin>(venue_owner_addr) == 35, EINVALID_BALANCE);
		
    }
}
