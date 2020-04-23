use 0x7257c2417e4d1038e1817c8f283ace2e::ViolasToken;

fun main(idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) {
    ViolasToken::make_order(idxa, amounta, idxb, amountb, data);
}
