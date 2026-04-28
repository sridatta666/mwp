import 'package:hive/hive.dart';
part 'timeline_model.g.dart';

@HiveType(typeId: 2)
class TimelineItem extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String workoutName;

  @HiveField(2)
  final bool isCompleted;

  TimelineItem({required this.date, required this.workoutName, required this.isCompleted});
}
