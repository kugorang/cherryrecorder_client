// HTML 스텁 구현 - 모바일 환경에서 사용
// dart:html의 기본 요소들을 단순하게 모방한 스텁 클래스

// DivElement 스텁
class DivElement {
  String? id;
  final Style style = Style();

  void append(dynamic child) {
    // 모바일에서는 작동하지 않음
  }

  void remove() {
    // 모바일에서는 작동하지 않음
  }
}

// Style 스텁
class Style {
  String? width;
  String? height;
  String? border;
  String? position;
}

// Document 스텁
final Document document = Document();

// Document 클래스 스텁
class Document {
  Element? head;
  Element? body;

  Element? getElementById(String id) => null;
  Element? querySelector(String selector) => null;

  Element createElement(String tagName) {
    return Element();
  }
}

// Element 스텁
class Element {
  String? id;
  Style style = Style();

  void append(dynamic child) {
    // 모바일에서는 작동하지 않음
  }
}

// ScriptElement 스텁
class ScriptElement extends Element {
  String? type;
  String? src;
  bool async = false;
  bool defer = false;
}
