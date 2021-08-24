---
Title: "Comparing asm to Python bitecode"
Date: "2018-03-10"
Category: hacking
Tags: [python, asm]
draft: true
Author: Petr Tikilyaynen
description: "Seeing the cost of abstractions"
---

```asm
>>> from py_trie import PyTrie
>>> import dis
>>> tr = PyTrie()
>>> dis.dis(tr.find)
 44           0 LOAD_FAST                0 (self)
              3 LOAD_ATTR                0 (head)
              6 STORE_FAST               2 (cur)

 45           9 SETUP_LOOP              52 (to 64)
             12 LOAD_FAST                1 (word)
             15 GET_ITER
        >>   16 FOR_ITER                44 (to 63)
             19 STORE_FAST               3 (char)

 46          22 LOAD_FAST                2 (cur)
             25 LOAD_ATTR                1 (children)
             28 LOAD_GLOBAL              2 (PyTrie)
             31 LOAD_ATTR                3 (char_to_idx)
             34 LOAD_FAST                3 (char)
             37 CALL_FUNCTION            1 (1 positional, 0 keyword pair)
             40 BINARY_SUBSCR
             41 STORE_FAST               4 (child)

 47          44 LOAD_FAST                4 (child)
             47 POP_JUMP_IF_TRUE        54

 48          50 LOAD_CONST               1 (False)
             53 RETURN_VALUE

 49     >>   54 LOAD_FAST                4 (child)
             57 STORE_FAST               2 (cur)
             60 JUMP_ABSOLUTE           16
        >>   63 POP_BLOCK

 51     >>   64 LOAD_FAST                2 (cur)
             67 LOAD_ATTR                4 (is_word)
             70 LOAD_CONST               2 (True)
             73 COMPARE_OP               2 (==)
             76 RETURN_VALUE


```


```asm
b50:	55                   	push   %rbp
 b51:	53                   	push   %rbx
 b52:	48 89 fb             	mov    %rdi,%rbx
 b55:	48 89 f7             	mov    %rsi,%rdi
 b58:	48 8d 35 0e 02 00 00 	lea    0x20e(%rip),%rsi        # d6d <_fini+0x9>
 b5f:	48 83 ec 28          	sub    $0x28,%rsp
 b63:	64 48 8b 04 25 28 00 	mov    %fs:0x28,%rax
 b6a:	00 00 
 b6c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 b71:	31 c0                	xor    %eax,%eax
 b73:	48 8d 4c 24 0c       	lea    0xc(%rsp),%rcx
 b78:	48 8d 54 24 10       	lea    0x10(%rsp),%rdx
 b7d:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%rsp)
 b84:	00 
 b85:	e8 06 fe ff ff       	callq  990 <PyArg_ParseTuple@plt>
 b8a:	85 c0                	test   %eax,%eax
 b8c:	0f 84 7e 00 00 00    	je     c10 <trie_find+0xc0>
 b92:	8b 44 24 0c          	mov    0xc(%rsp),%eax
 b96:	48 8b 6b 10          	mov    0x10(%rbx),%rbp
 b9a:	83 e8 01             	sub    $0x1,%eax
 b9d:	85 c0                	test   %eax,%eax
 b9f:	7e 5f                	jle    c00 <trie_find+0xb0>
 ba1:	31 db                	xor    %ebx,%ebx
 ba3:	eb 29                	jmp    bce <trie_find+0x7e>
 ba5:	0f 1f 00             	nopl   (%rax)
 ba8:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 bad:	48 63 c3             	movslq %ebx,%rax
 bb0:	83 c3 01             	add    $0x1,%ebx
 bb3:	0f be 3c 02          	movsbl (%rdx,%rax,1),%edi
 bb7:	e8 84 ff ff ff       	callq  b40 <char_to_ascii>
 bbc:	48 98                	cltq   
 bbe:	48 8b 6c c5 00       	mov    0x0(%rbp,%rax,8),%rbp
 bc3:	8b 44 24 0c          	mov    0xc(%rsp),%eax
 bc7:	83 e8 01             	sub    $0x1,%eax
 bca:	39 d8                	cmp    %ebx,%eax
 bcc:	7e 32                	jle    c00 <trie_find+0xb0>
 bce:	48 85 ed             	test   %rbp,%rbp
 bd1:	75 d5                	jne    ba8 <trie_find+0x58>
 bd3:	31 f6                	xor    %esi,%esi
 bd5:	48 8d 3d 94 01 00 00 	lea    0x194(%rip),%rdi        # d70 <_fini+0xc>
 bdc:	31 c0                	xor    %eax,%eax
 bde:	e8 7d fd ff ff       	callq  960 <Py_BuildValue@plt>
 be3:	48 8b 4c 24 18       	mov    0x18(%rsp),%rcx
 be8:	64 48 33 0c 25 28 00 	xor    %fs:0x28,%rcx
 bef:	00 00 
 bf1:	75 21                	jne    c14 <trie_find+0xc4>
 bf3:	48 83 c4 28          	add    $0x28,%rsp
 bf7:	5b                   	pop    %rbx
 bf8:	5d                   	pop    %rbp
 bf9:	c3                   	retq   
 bfa:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 c00:	48 85 ed             	test   %rbp,%rbp
 c03:	74 ce                	je     bd3 <trie_find+0x83>
 c05:	0f be b5 d1 00 00 00 	movsbl 0xd1(%rbp),%esi
 c0c:	eb c7                	jmp    bd5 <trie_find+0x85>
 c0e:	66 90                	xchg   %ax,%ax
 c10:	31 c0                	xor    %eax,%eax
 c12:	eb cf                	jmp    be3 <trie_find+0x93>
 c14:	e8 17 fd ff ff       	callq  930 <__stack_chk_fail@plt>
 c19:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)

```
