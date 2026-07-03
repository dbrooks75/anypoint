%dw 2.0
output application/java
---
payload reduce (item, acc = {}) ->
    acc ++ {(item.Name as String): item}
