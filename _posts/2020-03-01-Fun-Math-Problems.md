---
title: Fun Math Problems
description: A collection of interesting brain teasers and math puzzles that don't require specialized knowledge - just creativity and logical thinking.
categories: [STEM]
tags: [math, puzzles, probability, number-theory, combinatorics]
math: true
hidden: true
---

I love a good math puzzle. There's something deeply satisfying about working through a problem that seems complex at first but reveals elegant patterns once you dig in. Here are some interesting brain teasers I've collected over time - they're accessible to anyone and don't require specialized mathematical knowledge, just creativity and logical thinking.

## Palindromic Probability

**Problem:** Let $p$ be a random palindromic number such that $1000 \leq p \leq 10000$. What is the probability that $p^2$ is divisible by 7?

**Solution:**

First, we need to count how many palindromes exist in our range. A 4-digit palindrome has the form $\overline{abba}$ where the first and last digits are the same, and the middle two digits are the same.

Since $p$ is a 4-digit number, the first digit $a$ cannot be 0, giving us 9 choices for $a$ (1-9) and 10 choices for $b$ (0-9). Total palindromes: $9 \times 10 = 90$.

Now for divisibility by 7. Here's a key insight: if a number is divisible by 7, its square is also divisible by 7. This is because if $n = 7k$, then $n^2 = (7k)^2 = 49k^2 = 7(7k^2)$.

So we only need to check when $p$ is divisible by 7.

Writing $p = \overline{abba} = 1000a + 100b + 10b + a = 1001a + 110b$.

Since $1001 = 7 \times 143$, the term $1001a$ is always divisible by 7. However, $110 = 7 \times 15 + 5$, so $110b$ is divisible by 7 only when $b$ is divisible by 7.

Therefore, $b$ can only be 0 or 7, while $a$ can be any digit from 1 to 9.

Number of valid palindromes: $2 \times 9 = 18$

Probability: $\frac{18}{90} = \frac{1}{5} = 0.2$

## Arithmetic Sequence Challenge

**Problem:** Let $a_n$ and $b_n$ be arithmetic sequences with $a_1 = b_1 = 1$, such that $1 < a_n < b_n$ and $a_n \cdot b_n = 2010$. What is the largest possible value of $n$?

**Solution:**

Since $a_n \cdot b_n = 2010$, both $a_n$ and $b_n$ must be factors of 2010.

First, let's factor 2010: $2010 = 2 \times 3 \times 5 \times 67$

The factor pairs $(a_n, b_n)$ where $1 < a_n < b_n$ are:
- $(2, 1005)$, $(3, 670)$, $(5, 402)$, $(6, 335)$, $(10, 201)$, $(15, 134)$, $(30, 67)$

For arithmetic sequences starting at 1:
- $a_n = 1 + d_a(n-1)$
- $b_n = 1 + d_b(n-1)$

This gives us:
- $a_n - 1 = d_a(n-1)$  
- $b_n - 1 = d_b(n-1)$

To maximize $n$, we need to maximize $n-1$, which equals $\gcd(a_n-1, b_n-1)$.

Checking each factor pair:
- $(2,1005)$: $\gcd(1,1004) = 1$
- $(3,670)$: $\gcd(2,669) = 1$  
- $(5,402)$: $\gcd(4,401) = 1$
- $(6,335)$: $\gcd(5,334) = 1$
- $(10,201)$: $\gcd(9,200) = 1$
- $(15,134)$: $\gcd(14,133) = 7$
- $(30,67)$: $\gcd(29,66) = 1$

The largest value of $n-1$ is 7, so the maximum value of $n$ is **8**.

## Lattice Path Problem

**Problem:** In how many ways can we move from point $(-4,-4)$ to point $(4,4)$, without entering the square $\{(x,y): -2 \leq x,y \leq 2\}$? You can only move right by one or up by one, and you're allowed to touch the edge of the square but not enter it.

**Solution:**

This is a classic lattice path problem with obstacles. We can solve it using dynamic programming.

The key insight is that the number of ways to reach any point is the sum of ways to reach the points directly below it and directly to its left (since we can only move right or up).

For points inside the forbidden square, we set the number of paths to 0.

Let $f(x,y)$ be the number of ways to reach point $(x,y)$ from $(-4,-4)$.

Base case: $f(-4,-4) = 1$

Recurrence relation:
- If $(x,y)$ is inside the forbidden square: $f(x,y) = 0$
- Otherwise: $f(x,y) = f(x-1,y) + f(x,y-1)$

Working through the calculation systematically (imagine a grid where we fill in the number of paths to each point), we eventually reach $f(4,4) = \boxed{2112}$.

The calculation involves carefully tracking paths that go around the obstacle, either above it or below it, and counting all valid combinations.

---

These problems showcase different areas of mathematics - number theory, sequences, and combinatorics - but all share the common thread of having elegant solutions once you find the right approach. The key is often recognizing patterns or finding ways to simplify the problem by leveraging mathematical properties.

> **Problem-solving tip:** When stuck on a math puzzle, try working backwards from the solution, looking for symmetries, or breaking the problem into smaller, manageable pieces.
{: .prompt-tip }