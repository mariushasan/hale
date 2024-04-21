import random


class Node:
    def __init__(self, value):
        self.value = value
        self.left = None
        self.right = None


class TreeSet:
    def __init__(self):
        self.root = None
        self.height = 0

    def add(self, value):
        if not self.root:
            self.root = Node(value)
            return

        newHeight = 0

        node = self.root
        while True:
            newHeight += 1

            if newHeight > self.height:
                self.height = newHeight

            if node.value == value:
                return
            if node.value > value:
                if not node.left:
                    node.left = Node(value)
                    return
                node = node.left
            else:
                if not node.right:
                    node.right = Node(value)
                    return
                node = node.right

    def __contains__(self, value):
        if not self.root:
            return False

        node = self.root
        while node:
            if node.value == value:
                return True
            if node.value > value:
                node = node.left
            else:
                node = node.right

        return False

    def __repr__(self):
        items = []
        self.traverse(self.root, items)
        return str(items)

    def traverse(self, node, items):
        if not node:
            return
        self.traverse(node.left, items)
        items.append(node.value)
        self.traverse(node.right, items)

    def getHeight(self):
        return self.height


s1 = TreeSet()
s2 = TreeSet()

for i in range(1, 1001):
    s1.add(i)

print("height 1: " + str(s1.getHeight()))

added = set()

for i in range(1000):
    while True:
        randnum = random.randint(1, 1000)
        if randnum not in added:
            s2.add(randnum)
            added.add(randnum)
            break

print("Height 2: " + str(s2.getHeight()))
