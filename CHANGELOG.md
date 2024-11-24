## 0.2.0
- Initial release.

## 0.2.1
- Drop unnecessary ORDER BY columns following a non-nullable and distinct column.

## 0.2.2
- Raise error when there is no non-nullable and distinct column in the configured order definition.

## 0.2.3
- Replace any existing order defined on the given ar_relation

## 0.2.4
- Allow changing limit param.

## 1.0.0
- Allow changing of ar_relation and order by default.
- Make error class names consistent.

## 2.0.0
- Use multi_json instead of locking clients into using Oj gem.

## 2.1.0
- Rails 7.1 support.

## 2.1.1
- Rails 7.2 and 8.0 support.