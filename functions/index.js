const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Runs every 5 minutes. Sends FCM push for tasks due within the next 5 minutes.
exports.sendTaskNotifications = onSchedule(
  { schedule: 'every 5 minutes', timeZone: 'Asia/Kuala_Lumpur' },
  async () => {
    const now = new Date();
    const windowEnd = new Date(now.getTime() + 5 * 60 * 1000);

    const [tasksSnap, configDoc] = await Promise.all([
      db.collection('tasks')
        .where('dueDateTime', '>=', admin.firestore.Timestamp.fromDate(now))
        .where('dueDateTime', '<=', admin.firestore.Timestamp.fromDate(windowEnd))
        .where('isCompleted', '==', false)
        .where('notified', '==', false)
        .get(),
      db.collection('config').doc('device').get(),
    ]);

    const fcmToken = configDoc.data()?.fcmToken;
    if (!fcmToken || tasksSnap.empty) return;

    const batch = db.batch();

    await Promise.all(
      tasksSnap.docs.map(async (doc) => {
        const task = doc.data();
        try {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Task Due',
              body: task.title,
            },
            data: { taskId: doc.id },
            android: {
              priority: 'high',
              notification: { channelId: 'tasks_channel' },
            },
          });
          batch.update(doc.ref, { notified: true });
        } catch (err) {
          console.error(`Failed to notify task ${doc.id}:`, err.message);
        }
      })
    );

    await batch.commit();
  }
);

// Resets `notified` flag for recurring tasks after they fire,
// scheduling the next occurrence.
exports.resetRecurringTasks = onSchedule(
  { schedule: 'every 24 hours', timeZone: 'Asia/Kuala_Lumpur' },
  async () => {
    const snap = await db.collection('tasks')
      .where('recurrence', '!=', 0)   // 0 = RecurrenceType.none
      .where('notified', '==', true)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const now = new Date();

    snap.docs.forEach((doc) => {
      const task = doc.data();
      const due = task.dueDateTime?.toDate();
      if (!due || due > now) return;

      let nextDue;
      switch (task.recurrence) {
        case 1: // daily
          nextDue = new Date(due.getTime() + 86400000);
          break;
        case 2: // weekly
          nextDue = new Date(due.getTime() + 7 * 86400000);
          break;
        case 3: // monthly
          nextDue = new Date(due);
          nextDue.setMonth(nextDue.getMonth() + 1);
          break;
        case 4: // specific weekday
          nextDue = new Date(due.getTime() + 7 * 86400000);
          break;
        default:
          return;
      }

      batch.update(doc.ref, {
        dueDateTime: admin.firestore.Timestamp.fromDate(nextDue),
        notified: false,
      });
    });

    await batch.commit();
  }
);
