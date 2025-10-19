class UserProfile {
  final String name;
  final String phone;
  final String points;

  UserProfile({required this.name, required this.phone, required this.points});
}

class Transaction {
  final String title;
  final String date;
  final String amount;
  final String status;

  Transaction({
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
  });
}
