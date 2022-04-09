module TicketTutorial::Tickets {
    use Std::Signer;
	use Std::Vector;
    use AptosFramework::TestCoin;
    
	struct ConcertTicket has key, store, drop {
		seat: vector<u8>,
		ticket_code: vector<u8>,
		price: u64
	}

	struct Venue has key {
		available_tickets: vector<ConcertTicket>,
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

	public fun init_venue(venue_owner: &signer, max_seats: u64) {
		let available_tickets = Vector::empty<ConcertTicket>();
		move_to<Venue>(venue_owner, Venue {available_tickets, max_seats})
	}

	public fun create_ticket(venue_owner: &signer, seat: vector<u8>, ticket_code: vector<u8>, price: u64) acquires Venue {
		let venue_owner_addr = Signer::address_of(venue_owner);
		assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
		let current_seat_count = available_ticket_count(venue_owner_addr);
		let venue = borrow_global_mut<Venue>(venue_owner_addr);
		assert!(current_seat_count < venue.max_seats, EMAX_SEATS);
		Vector::push_back(&mut venue.available_tickets, ConcertTicket {seat, ticket_code, price});
    }

	public fun available_ticket_count(venue_owner_addr: address): u64 acquires Venue {
		let venue = borrow_global<Venue>(venue_owner_addr);
		Vector::length<ConcertTicket>(&venue.available_tickets)
	}

	fun get_ticket_info(venue_owner_addr: address, seat:vector<u8>): (bool, vector<u8>, u64, u64) acquires Venue {
		assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
		let venue = borrow_global<Venue>(venue_owner_addr);
		let i = 0;
        let len = Vector::length<ConcertTicket>(&venue.available_tickets);
        while (i < len) {
			let ticket= Vector::borrow<ConcertTicket>(&venue.available_tickets, i);
			if (ticket.seat == seat) return (true, ticket.ticket_code, ticket.price, i);
            i = i + 1;
        };
	    return (false, b"", 0, 0)
	}

	public fun get_ticket_price(venue_owner_addr: address, seat:vector<u8>): (bool, u64) acquires Venue {
		let (success, _, price, _) = get_ticket_info(venue_owner_addr, seat);
		assert!(success, EINVALID_TICKET);
		return (success, price)
	}

	public fun purchase_ticket(buyer: &signer, venue_owner_addr: address, seat: vector<u8>) acquires Venue, TicketEnvelope {
		
		let buyer_addr = Signer::address_of(buyer);
		let (success, _, price, index) = get_ticket_info(venue_owner_addr, seat);
		assert!(success, EINVALID_TICKET);		
		
		let venue = borrow_global_mut<Venue>(venue_owner_addr);
		TestCoin::transfer_internal(buyer, venue_owner_addr, price);
		let ticket = Vector::remove<ConcertTicket>(&mut venue.available_tickets, index);

		if (!exists<TicketEnvelope>(buyer_addr)) {
			move_to<TicketEnvelope>(buyer, TicketEnvelope {tickets: Vector::empty<ConcertTicket>()});
		};	
		let envelope = borrow_global_mut<TicketEnvelope>(buyer_addr);
		Vector::push_back<ConcertTicket>(&mut envelope.tickets, ticket);
	}

	#[test(venue_owner = @0x1, buyer = @0x2, faucet = @CoreResources)]
    public(script) fun sender_can_buy_ticket(venue_owner: signer, buyer: signer, faucet: signer) acquires Venue, TicketEnvelope {
		
		let venue_owner_addr = Signer::address_of(&venue_owner);

		// initialize the venue
		init_venue(&venue_owner, 3);
		assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);

		// create some tickets
		create_ticket(&venue_owner, b"A24", b"AB43C7F", 15);
		create_ticket(&venue_owner, b"A25", b"AB43CFD", 15);
		create_ticket(&venue_owner, b"A26", b"AB13C7F", 20);

		// verify we have 3 tickets now
		assert!(available_ticket_count(venue_owner_addr)==3, EINVALID_TICKET_COUNT);

		// verify seat and price
		let (success, price) = get_ticket_price(venue_owner_addr, b"A24");
		assert!(success, EINVALID_TICKET);
		assert!(price==15, EINVALID_PRICE);

		// initialize & fund account to buy tickets
        TestCoin::initialize(&faucet, 1000000);
        TestCoin::register(&venue_owner);
		TestCoin::register(&buyer);
        let amount = 1000;
        let faucet_addr = Signer::address_of(&faucet);
        let buyer_addr = Signer::address_of(&buyer);
        TestCoin::mint_internal(&faucet, faucet_addr, amount);
        TestCoin::transfer(faucet, buyer_addr, 100);
        assert!(TestCoin::balance_of(buyer_addr) == 100, EINVALID_BALANCE);

		// buy a ticket and confirm account balance changes
		purchase_ticket(&buyer, venue_owner_addr, b"A24");
		assert!(exists<TicketEnvelope>(buyer_addr), ENO_ENVELOPE);
        assert!(TestCoin::balance_of(buyer_addr) == 85, EINVALID_BALANCE);
		assert!(TestCoin::balance_of(venue_owner_addr) == 15, EINVALID_BALANCE);
	    assert!(available_ticket_count(venue_owner_addr)==2, EINVALID_TICKET_COUNT);

		// buy a second ticket & ensure balance has changed by 20
		purchase_ticket(&buyer, venue_owner_addr, b"A26");
		assert!(TestCoin::balance_of(buyer_addr) == 65, EINVALID_BALANCE);
		assert!(TestCoin::balance_of(venue_owner_addr) == 35, EINVALID_BALANCE);
		
    }
}
