/* PhaseTimerController（フェーズタイマー管理機能）
目的：全体議論・個別議論・怪しい人の発表・質問・投票 などの時間制限付きフェーズの制御
必要機能：
各フェーズに対応するタイマーと進行状態（GameFlowWatcherと連携）
時間切れで次フェーズに自動進行
タイマーの残り時間をプレイヤーに見せるUIコンポーネント
*/
import 'dart:async';
import 'package:flutter/material.dart';

/// フェーズ種別の列挙
enum GamePhase {
  discussion,
  privateDiscussion,
  suspicionAnnounce,
  question,
  voting,
  result,
}

/// フェーズごとのデフォルト時間（秒）
const Map<GamePhase, int> defaultPhaseDurations = {
  GamePhase.discussion: 180,         // 3分
  GamePhase.privateDiscussion: 60,   // 1分
  GamePhase.suspicionAnnounce: 45,   // 45秒
  GamePhase.question: 90,            // 1分30秒
  GamePhase.voting: 60,              // 1分
  GamePhase.result: 9999,            // 制限なし(仮)
};

/// フェーズタイマー管理クラス
class PhaseTimerController extends ChangeNotifier {
  GamePhase _currentPhase;
  int _secondsLeft;
  Timer? _timer;
  bool _isRunning = false;

  /// フェーズ切り替え時に呼ばれるコールバック
  final void Function(GamePhase nextPhase)? onPhaseChanged;
  /// タイマーが0になった時に呼ばれるコールバック
  final void Function(GamePhase finishedPhase)? onPhaseTimeout;

  PhaseTimerController({
    required GamePhase initialPhase,
    this.onPhaseChanged,
    this.onPhaseTimeout,
  })  : _currentPhase = initialPhase,
        _secondsLeft = defaultPhaseDurations[initialPhase] ?? 60;

  GamePhase get currentPhase => _currentPhase;
  int get secondsLeft => _secondsLeft;
  bool get isRunning => _isRunning;

  void start() {
    _isRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _isRunning = false;
        notifyListeners();
        if (onPhaseTimeout != null) {
          onPhaseTimeout!(_currentPhase);
        }
      }
    });
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _isRunning = false;
    notifyListeners();
  }

  void resume() {
    if (!_isRunning && _secondsLeft > 0) {
      start();
    }
  }

  void reset([int? seconds]) {
    _timer?.cancel();
    _isRunning = false;
    _secondsLeft = seconds ?? defaultPhaseDurations[_currentPhase] ?? 60;
    notifyListeners();
  }

  void nextPhase(GamePhase next) {
    _timer?.cancel();
    _isRunning = false;
    _currentPhase = next;
    _secondsLeft = defaultPhaseDurations[next] ?? 60;
    notifyListeners();
    if (onPhaseChanged != null) {
      onPhaseChanged!(next);
    }
    start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// タイマーUIウィジェット
class PhaseTimerWidget extends StatelessWidget {
  final PhaseTimerController controller;
  final Map<GamePhase, String> phaseLabels;

  const PhaseTimerWidget({
    Key? key,
    required this.controller,
    this.phaseLabels = const {
      GamePhase.discussion: "全体議論",
      GamePhase.privateDiscussion: "個別議論",
      GamePhase.suspicionAnnounce: "怪しい人発表",
      GamePhase.question: "質問",
      GamePhase.voting: "投票",
      GamePhase.result: "結果発表",
    },
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final min = (controller.secondsLeft ~/ 60).toString().padLeft(2, '0');
        final sec = (controller.secondsLeft % 60).toString().padLeft(2, '0');
        return Card(
          color: Colors.deepPurple[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  '${phaseLabels[controller.currentPhase] ?? "進行中"}：$min:$sec',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: controller.secondsLeft <= 10 ? Colors.red : Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}