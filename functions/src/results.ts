import {onDocumentWritten} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

/**
 * Fetches the name of a course from Firestore.
 * @param {string} courseId The ID of the course.
 * @return {Promise<string>} The name of the course or "Unknown Course".
 */
async function getCourseName(courseId: string): Promise<string> {
  try {
    const courseDoc = await db.collection("courses").doc(courseId).get();
    return courseDoc.data()?.["course_name"] ?? "Unknown Course";
  } catch (error) {
    logger.error(`Error fetching course name for ${courseId}:`, error);
    return "Unknown Course";
  }
}

/**
 * Updates a student's result document for a specific course and category.
 * @param {string} studentId The ID of the student.
 * @param {string} courseId The ID of the course.
 * @param {string} category The category to update (e.g., "assignments").
 * @param {object} data The data to set for the category.
 * @param {number} data.obtainedMarks The marks obtained by the student.
 * @param {number} data.totalMarks The total possible marks.
 * @return {Promise<admin.firestore.WriteResult>} A promise that resolves
 * when the document is updated.
 */
async function updateResult(
  studentId: string,
  courseId: string,
  category: string,
  data: {obtainedMarks: number; totalMarks: number}
) {
  const resultRef = db
    .collection("results")
    .doc(studentId)
    .collection("courses")
    .doc(courseId);

  const courseName = await getCourseName(courseId);

  logger.info(
    `Updating results for student ${studentId}, course ${courseId}`,
    `category ${category}`,
    data
  );

  return resultRef.set(
    {
      courseName: courseName,
      [category]: data,
    },
    {merge: true}
  );
}

/**
 * Recalculates total assignment marks for a student in a course.
 * Triggered when an assignment submission is written.
 */
export const onAssignmentMarked = onDocumentWritten(
  {
    document: "courses/{courseId}/classes/{classId}/assignments/" +
      "{assignmentId}/submissions/{studentId}",
  },
  async (event) => {
    const {courseId, classId, studentId} = event.params;

    const assignmentsSnapshot = await db
      .collection("courses")
      .doc(courseId)
      .collection("classes")
      .doc(classId)
      .collection("assignments")
      .get();

    let totalMarks = 0;
    let obtainedMarks = 0;

    for (const assignmentDoc of assignmentsSnapshot.docs) {
      totalMarks += (assignmentDoc.data()["totalMarks"] as number) ?? 0;
      const submissionDoc = await assignmentDoc.ref
        .collection("submissions")
        .doc(studentId)
        .get();
      if (submissionDoc.exists) {
        obtainedMarks +=
          (submissionDoc.data()?.["marksObtained"] as number) ?? 0;
      }
    }

    await updateResult(studentId, courseId, "assignments", {
      obtainedMarks,
      totalMarks,
    });
  }
);

/**
 * Recalculates total quiz marks for a student in a course.
 * Triggered when a quiz submission is written.
 */
export const onQuizMarked = onDocumentWritten(
  {
    document: "courses/{courseId}/classes/{classId}/quizzes/" +
      "{quizId}/submissions/{studentId}",
  },
  async (event) => {
    const {courseId, classId, studentId} = event.params;

    const quizzesSnapshot = await db
      .collection("courses")
      .doc(courseId)
      .collection("classes")
      .doc(classId)
      .collection("quizzes")
      .get();

    let totalMarks = 0;
    let obtainedMarks = 0;

    for (const quizDoc of quizzesSnapshot.docs) {
      totalMarks += (quizDoc.data()["totalMarks"] as number) ?? 0;
      const submissionDoc = await quizDoc.ref
        .collection("submissions")
        .doc(studentId)
        .get();
      if (submissionDoc.exists) {
        obtainedMarks +=
          (submissionDoc.data()?.["marksObtained"] as number) ?? 0;
      }
    }

    await updateResult(studentId, courseId, "quizzes", {
      obtainedMarks,
      totalMarks,
    });
  }
);

/**
 * Recalculates midterm marks for a student in a course.
 * Triggered when a midterm submission is written.
 */
export const onMidtermMarked = onDocumentWritten(
  {
    document: "courses/{courseId}/classes/{classId}/midterm/" +
      "details/submissions/{studentId}",
  },
  async (event) => {
    const {courseId, classId, studentId} = event.params;

    const midtermDetailsDoc = await db
      .collection("courses")
      .doc(courseId)
      .collection("classes")
      .doc(classId)
      .collection("midterm")
      .doc("details")
      .get();

    let totalMarks = 0;
    let obtainedMarks = 0;

    if (midtermDetailsDoc.exists) {
      totalMarks = (midtermDetailsDoc.data()?.["totalMarks"] as number) ?? 0;
      const submissionDoc = await midtermDetailsDoc.ref
        .collection("submissions")
        .doc(studentId)
        .get();
      if (submissionDoc.exists) {
        obtainedMarks =
          (submissionDoc.data()?.["marksObtained"] as number) ?? 0;
      }
    }

    await updateResult(studentId, courseId, "midterm", {
      obtainedMarks,
      totalMarks,
    });
  }
);

/**
 * Recalculates project marks for a student in a course.
 * Triggered when a project submission is written.
 */
export const onProjectMarked = onDocumentWritten(
  {
    document: "courses/{courseId}/classes/{classId}/project/" +
      "details/submissions/{studentId}",
  },
  async (event) => {
    const {courseId, classId, studentId} = event.params;

    const projectDetailsDoc = await db
      .collection("courses")
      .doc(courseId)
      .collection("classes")
      .doc(classId)
      .collection("project")
      .doc("details")
      .get();

    let totalMarks = 0;
    let obtainedMarks = 0;

    if (projectDetailsDoc.exists) {
      totalMarks = (projectDetailsDoc.data()?.["totalMarks"] as number) ?? 0;
      const submissionDoc = await projectDetailsDoc.ref
        .collection("submissions")
        .doc(studentId)
        .get();
      if (submissionDoc.exists) {
        obtainedMarks =
          (submissionDoc.data()?.["marksObtained"] as number) ?? 0;
      }
    }

    await updateResult(studentId, courseId, "project", {
      obtainedMarks,
      totalMarks,
    });
  }
);
