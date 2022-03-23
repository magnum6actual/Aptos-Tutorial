#[test_only]
module TicketTutorial::TicketsTests {
    //use Std::Signer;
	
    use Std::UnitTest;
    use Std::Vector;
    //use Std::ASCII;
    //use Tutorial::Tickets;

    fun get_account(): signer {
        Vector::pop_back(&mut UnitTest::create_signers_for_testing(1))
    }

    // #[test]
    // public(script) fun sender_can_assign_ticket() {
    //     let account = get_account();
    //     //let addr = Signer::address_of(&account);
    //     // Message::assign_ticket(account,  b"A24", b"FJKDSF");
    //     // assert!(
    //     //   Message::get_ticket_code(addr) == ASCII::string(b"FJKDSF"),
    //     //   0
    //     // );
	// 	Tickets::init_arena(account); 
    // }

	// #[test(account = @0x1)]
	// //#[expected_failure(abort_code = 0)]
    // public(script) fun sender_can_create_arena(account: signer) {
    //     let addr = Signer::address_of(&account);
    //     Tickets::init_arena(account);

	// 	assert!(exists<Tickets::Arena<Tickets::ConcertTicket>>(addr), 0);
    // }
}
