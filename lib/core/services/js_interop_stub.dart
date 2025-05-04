// JS interop 스텁 구현 - 모바일 환경에서 사용

// JSExport 어노테이션 스텁
class JSExport {
  final String? name;

  const JSExport([this.name]);
}

// anonymous 어노테이션 스텁
const anonymous = _Anonymous();

class _Anonymous {
  const _Anonymous();
}

// JS 확장 메서드 스텁
extension JSInteropExtension on Function {
  dynamic get toJS => this;
}
