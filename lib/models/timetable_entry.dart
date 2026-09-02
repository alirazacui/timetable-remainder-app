/// One lecture in your personal timetable: e.g. Monday, Period 4, class "NUR-N".
class TimetableEntry {
  String id;
  int weekday; // DateTime.monday..DateTime.friday (1..5)
  String periodSlotId; // links to a PeriodSlot.id
  String className; // "NUR-N", "Jr. I C", "KG-S" etc.
  String subject; // optional, e.g. "ICT" — can be left blank

  TimetableEntry({
    required this.id,
    required this.weekday,
    required this.periodSlotId,
    required this.className,
    this.subject = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekday': weekday,
        'periodSlotId': periodSlotId,
        'className': className,
        'subject': subject,
      };

  factory TimetableEntry.fromJson(Map<String, dynamic> json) =>
      TimetableEntry(
        id: json['id'],
        weekday: json['weekday'],
        periodSlotId: json['periodSlotId'],
        className: json['className'],
        subject: json['subject'] ?? '',
      );
}
