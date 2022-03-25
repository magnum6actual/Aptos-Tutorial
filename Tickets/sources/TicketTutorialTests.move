
// #[test_only]
// module TicketTutorial::TicketTests {
//     use Std::Signer;
//     use Std::UnitTest;
//     use Std::Vector;
//     //use Std::ASCII;
// //use AptosFramework::TestCoin;
//     use TicketTutorial::Tickets;

//     fun get_account(): signer {
//         Vector::pop_back(&mut UnitTest::create_signers_for_testing(1))
//     }
	
// 	#[test(buyer = @0x91f136d91934f57fd3a4bfe7512c0b99)]
//     public(script) fun sender_can_create_arena() {
// 		let owner = get_account();
// 		// TestCoin::transfer()
// 		// let buyer = get_account();
//         let owner_addr = Signer::address_of(&owner);

//         Tickets::init_arena(&owner);
		

// 		Tickets::create_ticket(&owner, b"A24", b"CDEFS");
// 		assert!(Tickets::available_ticket_count(owner_addr)==1, 1);
		
// 		// Tickets::purchase_ticket(&owner, &buyer);
// 		// assert!(Tickets::available_ticket_count(owner_addr)==1, 2);
//     }
// }