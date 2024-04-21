class CoursePlan:
    def __init__(self):
        self.courses = {}

    def add_course(self, course):
        if course not in self.courses:
            self.courses[course] = []
        
    def add_requisite(self, course1, course2):
        self.courses[course2].append(course1)

    def find_order(self):
        # TODO

if __name__ == "__main__":
    c = CoursePlan()
    c.add_course("Ohpe")
    c.add_course("Ohja")
    c.add_course("Tira")
    c.add_course("Jym")
    c.add_requisite("Ohpe", "Ohja")
    c.add_requisite("Ohja", "Tira")
    c.add_requisite("Jym", "Tira")
    print(c.find_order()) # esim. [Ohpe, Jym, Ohja, Tira]
    c.add_requisite("Tira", "Tira")
    print(c.find_order()) # None