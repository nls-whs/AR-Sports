# AR Sports

* Xcode 11 / Swift 5

* iOS >= 13.2

* iPad Pro 12.9 Portrait Support only

# Introduction

This prototype has been developed as part of [Next level Sports](https://hci.w-hs.de/research/projects/nextlevelsports/) project. Within this work, the question is examined whether Augmented Reality (AR) can be used as a tool to support the execution of rehabilitation exercises. Through this prototype, physiotherapists can use to record exercises for patients which can then later be selected and executed by the user.

During execution, the tracked body of the user is displayed by AR and compared with the previously recorded movements of the physiotherapist. The application  warns the user of possible misalignments or incorrect execution and help him with this to do the exercise correctly. After the unit, the application  gives the user feedback on the execution. There is also a possibility to save the tracked data for a later appointment with the physiotherapists.

# Installation instructions

1. Open the `ARSports.xcworkspace` file
2. If necessary, run `pod install` again from the console
4. Only tested and running on Apple iPad Pro 12.9
4. The application *Replica* is good for streaming the screen (pre-installed).

## Sequence of a recording

1. Select setup tab
2. Click on the "+" at the top
3. Camera View appears, click Record button below and record exercise.
4. Clicking the button again opens a dialog, enter the name here.
5. Now navigate back to the Setup tab and create the new exercise.
6. Set new key points of the movement on the first edit page.
7. Scrolling through the slider, the button above the slider adds a key point.
8. Click the Save button to save the exercise.
9. The new exercise should now exist in the Training tab.

# Credits

### Pictures

1. Fitness Icons: [001-Stretching](https://www.flaticon.com/free-icon/stretching_983544), [002-weight-lifting](https://www.flaticon.com/free-icon/weight-lifting_983536), [003-yoga](https://www.flaticon.com/free-icon/yoga_983566), [004-fitness](https://www.flaticon.com/free-icon/fitness_983527), [005-yoga](https://www.flaticon.com/free-icon/yoga_983543) : Used on the home screen and in the logo.

<div>Icons made by <a href="https://www.flaticon.com/authors/freepik" title="Freepik">Freepik</a> from <a href="https://www.flaticon. com/" title="Flaticon">www.flaticon.com</a></div>

2. [4-FunctionalTraining](https://www.freepik.com/free-photo/doing-kettlebell-squat-exercise_5399856.htm#page=1&query=squat&position=14): Used as the default exercise image
<a href="https://www.freepik.com/photos/woman">Woman photo created by pressfoto - www.freepik.com</a>

### Sounds

1. Result.wav : [Created by djlprojects on freesound.org](https://freesound.org/people/djlprojects/sounds/413629/) : Used to indicate successful completion of the complete exercise.

2. Rep.wav: [Created by rockwehrmann on freesound.org / CC0](https://freesound.org/people/rockwehrmann/sounds/72489/) : Used as a sound for a successful replay

3. Count.wav [Created by Christopherderp on freesound.org / CC0](https://freesound.org/people/Christopherderp/sounds/342200/) : Used as countdown sound.

### Third party libraries

#### Charts

​ Created by Daniel Cohen Gindi & Philipp Jahoda. Used to show statistics as PieChart.

* [Chart - Beautiful charts for iOS/tvOS/OSX! The Apple side of the crossplatform MPAndroidChart. ](https://github.com/danielgindi/Charts)

#### SoundSwifty

​ Created by [Adam Cichy](https://github.com/adamcichy) Used to play sound in the application.

* [SwiftySound - a simple library that lets you deal with Swift sounds easily.](https://github.com/adamcichy/SwiftySound)

#### Summerslider

​ Created by SuperbDerrick, [kang.derrick@gmail.com](mailto:kang.derrick@gmail.com). Used to show markers in the slider.

* [SummerSlider - iOS Custom Slider library](https://github.com/superbderrick/SummerSlider)

### Developer

Frederic Lotz
