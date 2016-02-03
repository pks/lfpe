<p>Press the 'Next' button to <strong>submit</strong> your post-edit and to request the next segment for post-edition.
Alternatively, in the textual interface, you may just press return when you finished the post-edit ('Target' text area is in focus).</p>

<p>The session can be paused at any time and continued later; However, if you have to pause your session, wait until the activity notification disappears and then press 'Pause', as we are collecting timing information. You may also just reload this site and re-request the segment to reset the timer.</p>

<p>Please use only a <strong>single browser window</strong> at the same time. Going back to earlier examples is not possible, please take great care when interacting with the system.</p>

<p><span style="border-bottom:1px solid #ccc">Instructions for the graphical interface:</span></p>
<p>To submit a post-edition in the graphical interface all phrases have to be marked as finished.</p>
<ul>
  <li><strong>Moving around:</strong> Press <strong>'S'</strong>, then select phrases using the arrow keys.</li>
  <li><strong>Editing text:</strong> Double click on a phrase or press <strong>'E'</strong> to edit the contents of the current phrase. Press 'Return' to save.</li>
  <li><strong>Reordering of target phrases:</strong> Press <strong>'M'</strong>, then use the arrow keys to move the selected phrase. Press 'Return' to fix the position.</li>
  <li><strong>Mark phrase as finished:</strong> Press <strong>'Return'</strong> to mark phrases as finished (press 'Return' again to undo). Moving, editing or deleting of finished phrases is not possible.</li>
  <li><strong>Adding target phrases:</strong> To add a phrase right next to the currently selected one press <strong>'A'</strong>.</li>
  <li><strong>Removing target phrases:</strong> Press <strong>'D'</strong> to delete the currently selected phrase.</li>
  <li><strong>Adding/removing alignments:</strong> Select a source phrase by clicking on it, then click on a suitable target phrase to connect or disconnect. Click the selected source phrase again to cancel.</li>
  <li><strong>Undo:</strong> Press <strong>'U'</strong> to undo alignments, text edits and deletion of phrases.</li>
  <li><strong>Reset:</strong> Click 'Reset' button to start from scratch.</li>
</ul>

<p>The interface was tested with Firefox 31, 38 and 43.</p>

<p><span style="border-bottom:1px solid #ccc">Known issues:</span></p>
<ul>
  <li>The width of the canvas of graphical editor may be to small when adding a lot of phrases.</li>
  <li>The in-line editor may change height and span several lines.</li>
  <li>When editing phrases that have no contents, the input box is lower than normal.</li>
  <li>Post-edits in the session overview may be partially tokenized due to phrase segmentation.</li>
  <li>Horizontal scrollbar doesn't follow highlighted phrase.</li>
  <li>Mouseover is not detected for undoing.</li>
  <li>The interface only works with Firefox.</li>
</ul>

<p class="tiny">
  Support: <a href="mailto://simianer@cl.uni-heidelberg.de">Mail</a>
</p>
<p class="tiny">Session: #<?php echo $_GET["key"]; ?> |
  <a href="http://coltrane.cl.uni-heidelberg.de:<?php echo $db->port; ?>/debug" target="_blank">Debug</a>
</p>

