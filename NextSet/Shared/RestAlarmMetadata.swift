#if os(iOS) && canImport(AlarmKit)
import AlarmKit

/// iOS 26 휴식 끝 알람(AlarmKit)의 메타데이터. 앱(`RestAlarm`)과 위젯(`RestAlarmLiveActivity`)이 같은 타입을 써야
/// 시스템이 "+30초 더 쉬기" 카운트다운 Live Activity 를 이 앱의 위젯으로 그린다. 담을 값은 없다.
@available(iOS 26.0, *)
struct RestAlarmMetadata: AlarmMetadata {}
#endif
